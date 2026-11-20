import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/utils.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class FormShell extends StatelessWidget {
  const FormShell({super.key, required this.title, required this.subtitle, required this.icon, required this.children});
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AppScaffold(
      title: title,
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: p.shadow, offset: const Offset(3, 4), blurRadius: 8)]),
          child: Row(children: [
            Icon(icon, size: 40, color: p.onPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: p.onPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        RaisedCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped(children))),
      ]),
    );
  }
}

Future<bool> _preview(BuildContext c, String body) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (x) => AlertDialog(
      title: const Text('पूर्वावलोकन'),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('संपादित करें')),
        FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('पुष्टि करें और सहेजें')),
      ],
    ),
  );
  return r == true;
}

// ====================== उधार एंट्री ======================
class UdharEntryScreen extends StatefulWidget {
  const UdharEntryScreen({super.key});
  @override
  State<UdharEntryScreen> createState() => _UdharEntryState();
}

class _UdharEntryState extends State<UdharEntryScreen> {
  TextEditingController nameC = TextEditingController();
  final mobC = TextEditingController(), prinC = TextEditingController(), rateC = TextEditingController();
  DateTime date = DateTime.now();
  bool busy = false;

  void onName(String v) {
    final s = context.read<AppState>();
    final m = s.memberByName(v);
    if (m != null) {
      mobC.text = '${m['Mobile_No'] ?? ''}';
      rateC.text = ns(s.memberRate);
    } else {
      final prev = s.loans.where((l) => l.name.toLowerCase() == v.trim().toLowerCase() && l.mobile.isNotEmpty).lastOrNull;
      if (prev != null) mobC.text = prev.mobile;
      rateC.text = ns(s.nonMemberRate);
    }
    setState(() {});
  }

  Future<void> save() async {
    final s = context.read<AppState>();
    final name = nameC.text.trim(), pr = toNum(prinC.text);
    if (name.isEmpty || pr <= 0) { toast(context, 'नाम और मूलधन भरें'); return; }
    final rate = toNum(rateC.text);
    final ok = await _preview(context, 'नाम: $name\nमोबाइल: ${mobC.text}\nदिनांक: ${fd(date)}\nमूलधन: ${rs(pr)}\nब्याज दर: ${ns(rate)}%');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await s.batch([
        {
          'op': 'add', 'sheet': 'Udhar_Khata',
          'row': {'Name': name, 'Mobile': mobC.text.trim(), 'Principal': pr, 'Date': iso(date), 'Rate': rate, 'Status': 'सक्रिय', 'Interest_Paid': 0, 'Principal_Paid': 0, 'Total_Paid': 0, 'Carry_Interest': 0},
        }
      ]);
      if (!mounted) return;
      await showWa(context, 'दिनाँक ${wa(date)}\n\n*$name* को ${rs(pr)} दिया।');
      nameC.clear(); mobC.clear(); prinC.clear(); rateC.clear();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return FormShell(
      title: 'उधार एंट्री',
      subtitle: 'कृपया सभी जानकारी सही सही भरें',
      icon: Icons.request_quote,
      children: [
        Autocomplete<String>(
          optionsBuilder: (v) => v.text.isEmpty ? const <String>[] : s.nameSuggestions.where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
          onSelected: onName,
          fieldViewBuilder: (c, ctrl, node, _) {
            nameC = ctrl;
            return AppField(label: 'नाम', hint: 'नाम चुनें या लिखें...', controller: ctrl, focusNode: node, required: true, onChanged: onName);
          },
        ),
        AppField(label: 'मोबाइल नंबर', hint: '10 अंकों का नंबर दर्ज करें', controller: mobC, keyboard: TextInputType.phone, maxLength: 10),
        DateField(label: 'दिनांक', value: date, required: true, onChanged: (d) => setState(() => date = d)),
        AppField(label: 'मूलधन', hint: 'राशि दर्ज करें...', controller: prinC, keyboard: numKb, required: true),
        AppField(label: 'ब्याज दर (% प्रति माह)', hint: 'ब्याज दर', controller: rateC, keyboard: numKb, required: true, suffix: const Icon(Icons.percent)),
        PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
      ],
    );
  }
}

// ====================== Repay panel (shared) ======================
class RepayForm extends StatefulWidget {
  const RepayForm({super.key, required this.loan, required this.onChanged});
  final Loan loan;
  final ValueChanged<RepayInput> onChanged;
  @override
  State<RepayForm> createState() => _RepayFormState();
}

class _RepayFormState extends State<RepayForm> {
  final fi = TextEditingController(), ip = TextEditingController(), pp = TextEditingController();
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => emit());
  }

  void emit() {
    widget.onChanged(RepayInput(widget.loan, toNum(fi.text), toNum(ip.text), toNum(pp.text), date));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final l = widget.loan;
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: p.textSecondary, fontSize: 12.5))),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: p.primary, fontSize: 13.5)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: p.mint, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
        child: Column(children: [
          line('दिनांक', fd(l.date)),
          line('मोबाइल नंबर', l.mobile.isEmpty ? '-' : l.mobile),
          line('मूलधन', rs(l.principal)),
          line('ब्याज दर', '${ns(l.rate)}%'),
          line('अवधि', '${l.daysTo(date)} दिन'),
          line('संभावित ब्याज', l.potentialText(date)),
        ]),
      ),
      AppField(label: 'अंतिम ब्याज', hint: 'अंतिम ब्याज लिखें', controller: fi, keyboard: numKb, onChanged: (_) => emit()),
      AppField(label: 'ब्याज जमा', hint: '0', controller: ip, keyboard: numKb, onChanged: (_) => emit()),
      AppField(label: 'मूलधन जमा', hint: '0', controller: pp, keyboard: numKb, onChanged: (_) => emit()),
      AppField(label: 'कुल जमा राशि', auto: true, controller: TextEditingController(text: ns(toNum(ip.text) + toNum(pp.text)))),
      DateField(label: 'जमा दिनांक', value: date, onChanged: (d) { date = d; emit(); }),
    ], 10));
  }
}

// ====================== उधार वापसी ======================
class WapsiScreen extends StatefulWidget {
  const WapsiScreen({super.key});
  @override
  State<WapsiScreen> createState() => _WapsiState();
}

class _WapsiState extends State<WapsiScreen> {
  String? name;
  String? dateKey;
  Loan? loan;
  RepayInput? input;
  bool busy = false;

  List<Loan> _forName(AppState s) => s.activeLoans.where((l) => l.name == name).toList();

  Future<void> save() async {
    final s = context.read<AppState>();
    final r = input;
    if (loan == null || r == null) return;
    if (!r.any) { toast(context, 'ब्याज जमा या मूलधन जमा भरें'); return; }
    final plan = planRepay(r);
    final ok = await _preview(context,
        '${loan!.name}\nऋण दिनांक: ${fd(loan!.date)}\nब्याज जमा: ${rs(r.intPaid)}\nमूलधन जमा: ${rs(r.prinPaid)}\nकुल जमा: ${rs(r.total)}${plan.note.isEmpty ? '' : '\n\n${plan.note}'}');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await s.batch([
        {'op': 'update', 'sheet': 'Udhar_Khata', 'id': loan!.id, 'row': plan.update},
        if (plan.newLoan != null) {'op': 'add', 'sheet': 'Udhar_Khata', 'row': plan.newLoan},
      ]);
      if (!mounted) return;
      await showWa(context,
          'दिनाँक ${wa(r.date)}\n\n*${loan!.name}*\n• ऋण दिनांक: ${wa(loan!.date)} (अवधि: ${loan!.daysTo(r.date)} दिन, ब्याज दर: ${ns(loan!.rate)}%)\n• मूलधन जमा: ${rs(r.prinPaid)}\n• ब्याज जमा: ${rs(r.intPaid)}\n• कुल जमा राशि: ${rs(r.total)}');
      setState(() { name = null; dateKey = null; loan = null; input = null; });
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final names = s.activeLoans.map((l) => l.name).toSet().toList()..sort();
    final mine = name == null ? <Loan>[] : _forName(s);
    final dates = mine.map((l) => iso(l.date)).toSet().toList()..sort();
    final sameDay = dateKey == null ? <Loan>[] : mine.where((l) => iso(l.date) == dateKey).toList();
    return FormShell(
      title: 'उधार वापसी',
      subtitle: 'कृपया सभी जानकारी सही सही भरें',
      icon: Icons.assignment_return,
      children: [
        AppDropdown<String>(
          label: 'नाम', required: true, hint: 'नाम चुनें...', value: name, items: names, labelOf: (e) => e,
          onChanged: (v) => setState(() {
            name = v; loan = null; input = null;
            final ds = s.activeLoans.where((l) => l.name == v).map((l) => iso(l.date)).toSet().toList();
            dateKey = ds.length == 1 ? ds.first : null;
            final same = s.activeLoans.where((l) => l.name == v && iso(l.date) == dateKey).toList();
            loan = same.length == 1 ? same.first : null;
          }),
        ),
        if (name != null)
          AppDropdown<String>(
            label: 'दिनांक', required: true, hint: 'दिनांक चुनें...', value: dateKey, items: dates, labelOf: (e) => fd(DateTime.parse(e)),
            onChanged: (v) => setState(() {
              dateKey = v; input = null;
              final same = mine.where((l) => iso(l.date) == v).toList();
              loan = same.length == 1 ? same.first : null;
            }),
          ),
        if (sameDay.length > 1)
          AppDropdown<Loan>(
            label: 'मूलधन', required: true, hint: 'मूलधन चुनें...', value: loan, items: sameDay, labelOf: (l) => rs(l.principal),
            onChanged: (v) => setState(() { loan = v; input = null; }),
          ),
        if (loan != null) RepayForm(key: ValueKey(loan!.id), loan: loan!, onChanged: (r) => input = r),
        if (loan != null) PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
      ],
    );
  }
}

// ====================== मासिक जमा ======================
class JamaEntryScreen extends StatefulWidget {
  const JamaEntryScreen({super.key});
  @override
  State<JamaEntryScreen> createState() => _JamaEntryState();
}

class _JamaEntryState extends State<JamaEntryScreen> {
  int year = DateTime.now().year, month = DateTime.now().month;
  final Map<String, Set<int>> sel = {};
  final Map<String, TextEditingController> adv = {};
  bool busy = false;

  int _idx(int y, int m) => y * 12 + (m - 1);

  Future<void> save() async {
    final s = context.read<AppState>();
    final monthly = s.monthly;
    final gs = s.groupStart;
    final cells = <Map<String, dynamic>>[], advOps = <Map<String, dynamic>>[], logs = <Map<String, dynamic>>[];
    final today = iso(DateTime.now());
    for (final m in s.activeMembers) {
      final mid = '${m['Member_ID']}';
      final checked = (sel[mid] ?? {}).toList()..sort();
      final typed = toNum(adv[mid]?.text);
      if (checked.isEmpty && typed <= 0) continue;
      var bal = s.advanceOf(mid) + typed;
      final paid = <int>[...checked];
      for (final _ in checked) { bal -= min(bal, monthly); } // existing advance reduces cash needed
      var last = max(_idx(year, month), checked.isEmpty ? 0 : checked.last);
      // remaining advance auto-pays upcoming unpaid months
      while (bal >= monthly && monthly > 0) {
        var i = last + 1;
        while (s.jamaAt(mid, i ~/ 12, i % 12 + 1) > 0 || paid.contains(i)) { i++; }
        paid.add(i);
        bal -= monthly;
        last = i;
      }
      for (final i in paid) {
        final y = i ~/ 12, mo = i % 12 + 1;
        cells.add({'Member_ID': mid, 'Name': '${m['Full_Name']}', 'Year': y, 'Month': mo, 'Amount': monthly});
        logs.add({'op': 'add', 'sheet': 'Jama_Log', 'row': {'Date': today, 'Member_ID': mid, 'Name': '${m['Full_Name']}', 'Month_Label': '${hiMonths[mo - 1]} $y', 'Amount': monthly}});
      }
      advOps.add({'Member_ID': mid, 'Balance': bal});
    }
    if (cells.isEmpty && advOps.isEmpty) { toast(context, 'कोई जमा चयनित नहीं है'); return; }
    if (!await confirm(context, '${cells.length} माह की जमा प्रविष्टि सहेजें?', yes: 'सहेजें')) return;
    setState(() => busy = true);
    try {
      await s.batch([{'op': 'saveJama', 'cells': cells, 'advance': advOps}, ...logs]);
      sel.clear();
      for (final c in adv.values) { c.clear(); }
      if (mounted) toast(context, 'जमा सहेज लिया गया');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    final gs = s.groupStart;
    final start = _idx(gs.year, gs.month), cur = _idx(year, month);
    final years = [for (var y = gs.year; y <= DateTime.now().year + 1; y++) y];
    return FormShell(
      title: 'मासिक जमा',
      subtitle: 'किश्त: ${rs(s.monthly)}',
      icon: Icons.calendar_month,
      children: [
        Row(children: [
          Expanded(child: AppDropdown<int>(label: 'माह', value: month, items: List.generate(12, (i) => i + 1), labelOf: (m) => hiMonths[m - 1], onChanged: (v) => setState(() => month = v ?? month))),
          const SizedBox(width: 10),
          Expanded(child: AppDropdown<int>(label: 'वर्ष', value: year, items: years, labelOf: (y) => '$y', onChanged: (v) => setState(() => year = v ?? year))),
        ]),
        for (final m in s.activeMembers)
          Builder(builder: (_) {
            final mid = '${m['Member_ID']}';
            final unpaid = [for (var i = start; i <= cur; i++) if (s.jamaAt(mid, i ~/ 12, i % 12 + 1) <= 0) i];
            final paidNow = s.jamaAt(mid, year, month);
            final advBal = s.advanceOf(mid);
            adv.putIfAbsent(mid, () => TextEditingController());
            return RaisedCard(
              color: p.input,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${m['Full_Name']}', style: TextStyle(fontWeight: FontWeight.w800, color: p.deep, fontSize: 15))),
                  if (advBal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppPalette.amber.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                      child: Text('एडवांस ${rs(advBal)}', style: const TextStyle(color: AppPalette.amber, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ]),
                const SizedBox(height: 6),
                if (paidNow > 0) Text('${hiMonths[month - 1]} $year: जमा ✓ ${rs(paidNow)}', style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
                if (unpaid.isNotEmpty)
                  Wrap(spacing: 6, children: [
                    for (final i in unpaid)
                      FilterChip(
                        label: Text('${hiMonthsShort[i % 12]} ${(i ~/ 12) % 100}', style: const TextStyle(fontSize: 12)),
                        selected: (sel[mid] ?? {}).contains(i),
                        onSelected: (v) => setState(() { final st = sel.putIfAbsent(mid, () => {}); v ? st.add(i) : st.remove(i); }),
                      ),
                  ]),
                const SizedBox(height: 8),
                AppField(label: 'एडवांस राशि (अगले महीनों में समायोजित)', hint: '0', controller: adv[mid], keyboard: numKb),
              ]),
            );
          }),
        PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
      ],
    );
  }
}

// ====================== खर्च ======================
class KharchScreen extends StatefulWidget {
  const KharchScreen({super.key});
  @override
  State<KharchScreen> createState() => _KharchState();
}

class _KharchState extends State<KharchScreen> {
  final vC = TextEditingController(), aC = TextEditingController();
  DateTime date = DateTime.now();
  bool busy = false;

  Future<void> save() async {
    final s = context.read<AppState>();
    if (vC.text.trim().isEmpty || toNum(aC.text) <= 0) { toast(context, 'विवरण और राशि भरें'); return; }
    setState(() => busy = true);
    try {
      await s.batch([{'op': 'add', 'sheet': 'Kharch', 'row': {'Date': iso(date), 'Details': vC.text.trim(), 'Amount': toNum(aC.text)}}]);
      vC.clear(); aC.clear();
      if (mounted) toast(context, 'खर्च सहेज लिया गया');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormShell(
        title: 'खर्च', subtitle: 'संचालन एवं अन्य खर्च', icon: Icons.receipt_long,
        children: [
          AppField(label: 'विवरण', hint: 'खर्च का विवरण / कारण', controller: vC, required: true),
          AppField(label: 'राशि', hint: 'राशि दर्ज करें...', controller: aC, keyboard: numKb, required: true),
          DateField(label: 'दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
          PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
        ],
      );
}

// ====================== अतिरिक्त राशि ======================
class AtiriktScreen extends StatefulWidget {
  const AtiriktScreen({super.key});
  @override
  State<AtiriktScreen> createState() => _AtiriktState();
}

class _AtiriktState extends State<AtiriktScreen> {
  final aC = TextEditingController();
  bool busy = false;

  Future<void> save() async {
    final s = context.read<AppState>();
    if (toNum(aC.text) <= 0) { toast(context, 'राशि भरें'); return; }
    setState(() => busy = true);
    try {
      await s.batch([{'op': 'add', 'sheet': 'Atirikt_Rashi', 'row': {'Date': iso(DateTime.now()), 'Amount': toNum(aC.text), 'Note': 'रजिस्टर और कैश मेल न खाने पर अतिरिक्त राशि'}}]);
      aC.clear();
      if (mounted) toast(context, 'अतिरिक्त राशि सहेज ली गई');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormShell(
        title: 'अतिरिक्त राशि', subtitle: 'रजिस्टर और कैश मेल न खाने पर', icon: Icons.add_card,
        children: [
          AppField(label: 'राशि', hint: 'राशि दर्ज करें...', controller: aC, keyboard: numKb, required: true),
          PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
        ],
      );
}

// ====================== पैसा वितरण ======================
class VitranScreen extends StatefulWidget {
  const VitranScreen({super.key});
  @override
  State<VitranScreen> createState() => _VitranState();
}

class _VitranState extends State<VitranScreen> {
  final perC = TextEditingController();
  DateTime date = DateTime.now();
  final Set<String> ticked = {};
  final Map<String, RepayInput> inputs = {}; // loanId -> input
  bool busy = false;

  List<Loan> _loansOf(AppState s, Map<String, dynamic> m) => s.activeLoans.where((l) => l.name.toLowerCase() == '${m['Full_Name']}'.trim().toLowerCase()).toList();

  num _adjust(AppState s, Map<String, dynamic> m) {
    if (!ticked.contains('${m['Member_ID']}')) return 0;
    return _loansOf(s, m).fold<num>(0, (a, l) => a + (inputs[l.id]?.total ?? 0));
  }

  Future<void> save() async {
    final s = context.read<AppState>();
    final per = toNum(perC.text);
    if (per <= 0) { toast(context, 'वितरण राशि भरें'); return; }
    final ms = s.activeMembers;
    final ops = <Map<String, dynamic>>[];
    for (final m in ms) {
      final mid = '${m['Member_ID']}';
      if (ticked.contains(mid)) {
        for (final l in _loansOf(s, m)) {
          final r = inputs[l.id];
          if (r == null || !r.any) continue;
          final plan = planRepay(r);
          ops.add({'op': 'update', 'sheet': 'Udhar_Khata', 'id': l.id, 'row': plan.update});
          if (plan.newLoan != null) ops.add({'op': 'add', 'sheet': 'Udhar_Khata', 'row': plan.newLoan});
        }
      }
      final adj = _adjust(s, m);
      ops.add({
        'op': 'add', 'sheet': 'Paisa_Vitran',
        'row': {'Date': iso(date), 'Total_Amount': per * ms.length, 'Per_Member': per, 'Member_ID': mid, 'Member_Name': '${m['Full_Name']}', 'Adjustment': adj, 'Final_Amount': per - adj},
      });
    }
    if (!await confirm(context, '${ms.length} सदस्यों को ${rs(per)} प्रति सदस्य वितरण सहेजें?', yes: 'सहेजें')) return;
    setState(() => busy = true);
    try {
      await s.batch(ops);
      perC.clear(); ticked.clear(); inputs.clear();
      if (mounted) toast(context, 'वितरण सहेज लिया गया');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    final per = toNum(perC.text);
    final ms = s.activeMembers;
    return FormShell(
      title: 'पैसा वितरण',
      subtitle: 'उपलब्ध राशि: ${rs(s.stats.balance)}',
      icon: Icons.payments,
      children: [
        AppField(label: 'कुल राशि', auto: true, controller: TextEditingController(text: ns(per * ms.length))),
        AppField(label: 'वितरण राशि (प्रति सदस्य)', hint: 'राशि दर्ज करें...', controller: perC, keyboard: numKb, required: true, onChanged: (_) => setState(() {})),
        DateField(label: 'दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
        for (final m in ms)
          Builder(builder: (_) {
            final mid = '${m['Member_ID']}';
            final ls = _loansOf(s, m);
            final adj = _adjust(s, m);
            return RaisedCard(
              color: p.input,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('${m['Full_Name']}', style: TextStyle(fontWeight: FontWeight.w800, color: p.deep))),
                  Text(rs(per - adj), style: TextStyle(fontWeight: FontWeight.w800, color: p.primary)),
                  if (ls.isNotEmpty)
                    Checkbox(value: ticked.contains(mid), onChanged: (v) => setState(() => v == true ? ticked.add(mid) : ticked.remove(mid))),
                ]),
                if (adj > 0) Text('उधार चुकता में घटाया: -${rs(adj)}', style: const TextStyle(color: AppPalette.red, fontSize: 12)),
                if (ls.isNotEmpty && ticked.contains(mid))
                  for (final l in ls) ...[
                    const SizedBox(height: 10),
                    Text('उधार: ${fd(l.date)} • ${rs(l.principal)}', style: TextStyle(fontWeight: FontWeight.w700, color: p.accent)),
                    const SizedBox(height: 6),
                    RepayForm(key: ValueKey(l.id), loan: l, onChanged: (r) { inputs[l.id] = r; WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); }); }),
                  ],
              ]),
            );
          }),
        PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: save, busy: busy),
      ],
    );
  }
}
