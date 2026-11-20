import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class PaisaVitranScreen extends StatefulWidget {
  const PaisaVitranScreen({super.key});
  @override
  State<PaisaVitranScreen> createState() => _PaisaVitranScreenState();
}

class _PaisaVitranScreenState extends State<PaisaVitranScreen> {
  final s = Store.I;
  final total = TextEditingController();
  final Map<String, TextEditingController> ctrl = {};
  DateTime date = DateTime.now();

  TextEditingController _c(String id) => ctrl.putIfAbsent(id, () => TextEditingController());

  void _equal() {
    final t = num0(total.text);
    if (t <= 0 || s.members.isEmpty) return;
    final each = (t / s.members.length).floorToDouble();
    for (final m in s.members) {
      _c(m.id).text = each.toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _save() async {
    final shares = <Member, double>{for (final m in s.members) m: num0(_c(m.id).text)}..removeWhere((k, v) => v <= 0);
    if (shares.isEmpty) return toast(context, 'किसी सदस्य की राशि लिखें');
    final sum = shares.values.fold(0.0, (a, e) => a + e);
    if (sum > s.fe.totalFund) return toast(context, 'कुल वितरण ${rs(sum)} फंड ${rs(s.fe.totalFund)} से ज़्यादा है');
    if (!await confirm(context, 'कुल ${rs(sum)} बाँटें? सदस्यों के सक्रिय उधार इसी में से समायोजित होंगे।')) return;
    shares.forEach((m, share) {
      final plans = s.fe.planSettlement(m.id, share, date);
      final settled = s.fe.settlementTotal(plans);
      for (final p in plans) {
        s.repay(p.loan, p.interest, p.principal, date, p.principal >= p.loan.principal - 0.5 ? 1 : 2, extra: '(वितरण से समायोजित)');
      }
      s.vitran.add(Vitran(id: s.newId(), memberId: m.id, share: share, loanSettled: settled, date: date));
    });
    await s.save();
    if (!mounted) return;
    setState(() {
      ctrl.clear();
      total.clear();
    });
    toast(context, 'वितरण दर्ज हो गया');
  }

  @override
  Widget build(BuildContext context) {
    final reg = [...s.vitran]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('पैसा वितरण')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (s.isAdmin)
          AppCard(child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: Text('उपलब्ध फंड: ${rs(s.fe.totalFund)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text))),
            const SizedBox(height: 8),
            DateField(label: 'वितरण दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
            Row(children: [
              Expanded(child: tf(total, 'कुल बाँटने योग्य राशि (₹)', number: true)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(onPressed: _equal, child: const Text('बराबर बाँटें'))),
            ]),
            for (final m in s.members) ...[
              tf(_c(m.id), m.name, number: true, onChanged: (_) => setState(() {})),
              Builder(builder: (_) {
                final sh = num0(_c(m.id).text);
                if (sh <= 0) return const SizedBox();
                final st = s.fe.settlementTotal(s.fe.planSettlement(m.id, sh, date));
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('उधार समायोजन ${rs(st)} • नेट भुगतान ${rs(sh - st)}', style: const TextStyle(fontSize: 12, color: C.accent)),
                  ),
                );
              }),
            ],
            btn('वितरण अंतिम करें', _save, icon: Icons.share),
          ])),
        sectionTitle('वितरण रजिस्टर'),
        if (reg.isEmpty) const AppCard(child: Text('अभी कोई वितरण नहीं', style: TextStyle(color: C.text2))),
        for (final v in reg)
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.memberById(v.memberId)?.name ?? ''} • ${dt(v.date)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
            Text('हिस्सा ${rs(v.share)} • उधार समायोजन ${rs(v.loanSettled)} • नेट ${rs(v.net)}', style: const TextStyle(color: C.text2)),
          ])),
      ]),
    );
  }
}
