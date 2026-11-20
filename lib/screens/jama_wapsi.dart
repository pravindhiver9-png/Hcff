import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/finance_engine.dart';
import '../services/store.dart';
import '../ui.dart';

class JamaWapsiScreen extends StatefulWidget {
  const JamaWapsiScreen({super.key});
  @override
  State<JamaWapsiScreen> createState() => _JamaWapsiScreenState();
}

class _JamaWapsiScreenState extends State<JamaWapsiScreen> {
  final s = Store.I;
  Loan? loan;
  DateTime date = DateTime.now();
  int cond = 1;
  final iC = TextEditingController(), pC = TextEditingController();

  void _recalc() {
    final l = loan;
    if (l == null) {
      setState(() {});
      return;
    }
    iC.text = FinanceEngine.accrued(l, date).toStringAsFixed(0);
    pC.text = cond == 1 ? l.principal.toStringAsFixed(0) : (cond == 2 ? '' : '0');
    setState(() {});
  }

  Future<void> _save() async {
    final l = loan;
    if (l == null) return toast(context, 'उधार चुनें');
    final i = num0(iC.text);
    final p = cond == 3 ? 0.0 : num0(pC.text);
    if (cond == 1 && p < l.principal - 0.5) return toast(context, 'पूर्ण जमा में पूरा मूलधन चाहिए');
    if (cond == 2 && (p <= 0 || p >= l.principal)) return toast(context, 'बचत मूलधन के लिए मूलधन जमा 0 से ज़्यादा और कुल मूलधन से कम हो');
    s.repay(l, i, p, date, cond);
    await s.save();
    if (!mounted) return;
    toast(context, 'जमा वापसी दर्ज हो गई');
    setState(() {
      loan = null;
      iC.clear();
      pC.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = s.loans.where((l) => l.active).toList();
    final l = loan;
    final rest = l == null ? 0.0 : l.principal - (cond == 3 ? 0 : num0(pC.text));
    return Scaffold(
      appBar: AppBar(title: const Text('जमा वापसी')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        AppCard(child: Column(children: [
          DropdownButtonFormField<Loan>(
            value: l,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'सक्रिय उधार चुनें'),
            items: [for (final x in active) DropdownMenuItem(value: x, child: Text('${x.borrower} • ${rs(x.principal)} • ${dt(x.date)}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              loan = v;
              _recalc();
            },
          ),
          const SizedBox(height: 10),
          DateField(label: 'जमा दिनांक', value: date, onChanged: (d) { date = d; _recalc(); }),
          RadioListTile<int>(contentPadding: EdgeInsets.zero, value: 1, groupValue: cond, title: const Text('1. पूर्ण जमा (मूलधन + ब्याज)'), onChanged: (v) { cond = v!; _recalc(); }),
          RadioListTile<int>(contentPadding: EdgeInsets.zero, value: 2, groupValue: cond, title: const Text('2. आंशिक मूलधन — बचत मूलधन नई एंट्री'), onChanged: (v) { cond = v!; _recalc(); }),
          RadioListTile<int>(contentPadding: EdgeInsets.zero, value: 3, groupValue: cond, title: const Text('3. 16वां दिन / "+" रोलओवर (सिर्फ़ ब्याज जमा)'), onChanged: (v) { cond = v!; _recalc(); }),
          tf(iC, 'ब्याज जमा (₹)', number: true),
          if (cond != 3) tf(pC, 'मूलधन जमा (₹)', number: true, onChanged: (_) => setState(() {})),
          if (l != null && cond != 1) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('नई सक्रिय एंट्री: ${rs(rest)} (${dt(date)} से)', style: const TextStyle(color: C.accent, fontWeight: FontWeight.bold))),
          btn('जमा सेव करें', _save, icon: Icons.save),
        ])),
      ]),
    );
  }
}

class JamaWapsiHistoryScreen extends StatelessWidget {
  const JamaWapsiHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = Store.I.loans.where((l) => l.repayDate != null).toList()..sort((a, b) => b.repayDate!.compareTo(a.repayDate!));
    return Scaffold(
      appBar: AppBar(title: const Text('जमा वापसी इतिहास')),
      body: list.isEmpty
          ? const Center(child: Text('अभी कोई जमा वापसी नहीं'))
          : ListView(padding: const EdgeInsets.all(12), children: [
              for (final l in list)
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l.borrower} • ${dt(l.repayDate!)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                  Text('ब्याज ${rs(l.interestPaid)} • मूलधन ${rs(l.principalPaid)} • कुल ${rs(l.interestPaid + l.principalPaid)}', style: const TextStyle(color: C.text2)),
                  if (l.note.isNotEmpty) Text(l.note, style: const TextStyle(fontSize: 12, color: C.accent)),
                ])),
            ]),
    );
  }
}
