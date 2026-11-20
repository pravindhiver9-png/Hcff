import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/finance_engine.dart';
import '../services/store.dart';
import '../ui.dart';

class MasikJamaScreen extends StatefulWidget {
  const MasikJamaScreen({super.key});
  @override
  State<MasikJamaScreen> createState() => _MasikJamaScreenState();
}

class _MasikJamaScreenState extends State<MasikJamaScreen> {
  final s = Store.I;
  String? memberId;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime date = DateTime.now();
  late final amount = TextEditingController(text: s.monthlyAmount.toStringAsFixed(0));

  String _label(String key) {
    final p = key.split('-');
    return DateFormat('MMM yyyy').format(DateTime(int.parse(p[0]), int.parse(p[1]), 1));
  }

  /// राशि मासिक किस्त से ज़्यादा हो तो अगले महीनों में अपने-आप बँट जाती है (एडवांस जमा)।
  Future<void> _save() async {
    if (memberId == null) return toast(context, 'सदस्य चुनें');
    final amt = num0(amount.text);
    if (amt <= 0) return toast(context, 'सही राशि लिखें');
    final per = s.monthlyAmount;
    var n = (amt / per).floor();
    if (n < 1) n = 1;
    final paid = s.fe.paidMonths(memberId!);
    var cur = month;
    var left = amt;
    final added = <String>[];
    for (var k = 0; k < n; k++) {
      while (paid.contains(FinanceEngine.monthKey(cur))) {
        cur = FinanceEngine.addMonths(cur, 1);
      }
      final a = (k == n - 1) ? left : per;
      s.jama.add(MasikJama(id: s.newId(), memberId: memberId!, month: FinanceEngine.monthKey(cur), amount: a, date: date));
      added.add(FinanceEngine.monthKey(cur));
      paid.add(FinanceEngine.monthKey(cur));
      left -= a;
    }
    await s.save();
    if (!mounted) return;
    toast(context, 'जमा दर्ज: ${added.map(_label).join(', ')}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fe = s.fe;
    final recent = [...s.jama]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('मासिक जमा')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (s.canEdit)
          AppCard(child: Column(children: [
            DropdownButtonFormField<String>(
              value: memberId,
              decoration: const InputDecoration(labelText: 'सदस्य चुनें'),
              items: [for (final m in s.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
              onChanged: (v) => setState(() => memberId = v),
            ),
            const SizedBox(height: 10),
            DateField(label: 'किस महीने से (कोई भी तारीख़ चुनें)', value: month, onChanged: (d) => setState(() => month = DateTime(d.year, d.month, 1))),
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('महीना: ${_label(FinanceEngine.monthKey(month))}', style: const TextStyle(color: C.accent)))),
            tf(amount, 'राशि (₹) — मासिक ${rs(s.monthlyAmount)}; ज़्यादा देने पर एडवांस अगले महीनों में जुड़ेगा', number: true),
            DateField(label: 'जमा दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
            btn('जमा सेव करें', _save, icon: Icons.save),
          ])),
        sectionTitle('सदस्यवार स्थिति'),
        for (final m in s.members)
          AppCard(child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
              Text('अंतिम जमा महीना: ${fe.lastPaidMonth(m.id) == null ? '-' : _label(fe.lastPaidMonth(m.id)!)}', style: const TextStyle(fontSize: 12, color: C.text2)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rs(fe.memberJama(m.id)), style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
              if (fe.advanceMonths(m.id) > 0) Text('एडवांस ${fe.advanceMonths(m.id)} माह', style: const TextStyle(fontSize: 12, color: C.ok)),
            ]),
          ])),
        sectionTitle('जमा रजिस्टर'),
        for (final j in recent)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(child: Text('${s.memberById(j.memberId)?.name ?? ''} • ${_label(j.month)}\n${dt(j.date)}', style: const TextStyle(color: C.text))),
              Text(rs(j.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: C.ok)),
              if (s.canEdit)
                IconButton(
                  icon: const Icon(Icons.delete, color: C.error),
                  onPressed: () async {
                    if (await confirm(context, 'यह जमा हटाएँ?')) {
                      s.jama.remove(j);
                      await s.save();
                      if (mounted) setState(() {});
                    }
                  },
                ),
            ]),
          ),
      ]),
    );
  }
}
