import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class UdharEntryScreen extends StatefulWidget {
  const UdharEntryScreen({super.key});
  @override
  State<UdharEntryScreen> createState() => _UdharEntryScreenState();
}

class _UdharEntryScreenState extends State<UdharEntryScreen> {
  final s = Store.I;
  String? memberId;
  bool outsider = false;
  final name = TextEditingController(), amount = TextEditingController(), note = TextEditingController();
  late final rate = TextEditingController(text: s.memberRate.toString());
  DateTime date = DateTime.now();

  Future<void> _save() async {
    final amt = num0(amount.text);
    final who = outsider ? name.text.trim() : (s.memberById(memberId)?.name ?? '');
    if (who.isEmpty) return toast(context, outsider ? 'नाम लिखें' : 'सदस्य चुनें');
    if (amt <= 0) return toast(context, 'सही राशि लिखें');
    if (amt > s.fe.totalFund && !await confirm(context, 'उधार राशि कुल फंड (${rs(s.fe.totalFund)}) से ज़्यादा है। फिर भी सेव करें?')) return;
    s.loans.add(Loan(id: s.newId(), memberId: outsider ? null : memberId, borrower: who, principal: amt, date: date, rate: num0(rate.text), note: note.text.trim()));
    await s.save();
    if (!mounted) return;
    toast(context, 'उधार दर्ज हो गया');
    setState(() {
      amount.clear();
      note.clear();
      name.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('उधार एंट्री')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('बाहरी व्यक्ति (सदस्य नहीं)'),
              value: outsider,
              onChanged: (v) => setState(() {
                outsider = v;
                rate.text = (v ? s.outsiderRate : s.memberRate).toString();
              }),
            ),
            if (outsider)
              tf(name, 'उधार लेने वाले का नाम')
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: memberId,
                  decoration: const InputDecoration(labelText: 'सदस्य चुनें'),
                  items: [for (final m in s.members) DropdownMenuItem(value: m.id, child: Text(m.name))],
                  onChanged: (v) => setState(() => memberId = v),
                ),
              ),
            tf(amount, 'मूलधन (₹)', number: true),
            tf(rate, 'ब्याज दर (% प्रति माह)', number: true),
            DateField(label: 'दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
            tf(note, 'नोट (वैकल्पिक)'),
            btn('उधार सेव करें', _save, icon: Icons.save),
          ])),
          Text('उपलब्ध फंड: ${rs(s.fe.totalFund)}', style: const TextStyle(color: C.text2)),
        ]),
      );
}
