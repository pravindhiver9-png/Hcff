import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/pdf_service.dart';
import '../services/store.dart';
import '../ui.dart';

class UdharListScreen extends StatefulWidget {
  const UdharListScreen({super.key});
  @override
  State<UdharListScreen> createState() => _UdharListScreenState();
}

class _UdharListScreenState extends State<UdharListScreen> {
  final s = Store.I;
  String filter = 'सभी'; // सभी | सक्रिय | पूर्ण जमा
  bool busy = false;

  List<Loan> get rows {
    final l = s.loans
        .where((x) => filter == 'सभी' || x.status == filter)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return l;
  }

  Future<void> _pdf() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final w = await PdfService.shareLoans(rows, filter);
      if (w != null && mounted) toast(context, w);
    } catch (e) {
      if (mounted) toast(context, 'PDF नहीं बन सकी: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(Loan l) async {
    final name = TextEditingController(text: l.borrower);
    final pr = TextEditingController(text: l.principal.toStringAsFixed(0));
    final rate = TextEditingController(text: l.rate.toString());
    final ip = TextEditingController(text: l.interestPaid.toStringAsFixed(0));
    final pp = TextEditingController(text: l.principalPaid.toStringAsFixed(0));
    final note = TextEditingController(text: l.note);
    var date = l.date;
    var status = l.status;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('उधार एंट्री बदलें'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              tf(name, 'नाम'),
              tf(pr, 'मूलधन', number: true),
              tf(rate, 'ब्याज दर %', number: true),
              DateField(label: 'दिनांक', value: date, onChanged: (d) => setLocal(() => date = d)),
              tf(ip, 'ब्याज जमा', number: true),
              tf(pp, 'मूलधन जमा', number: true),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'स्थिति'),
                items: const [
                  DropdownMenuItem(value: 'सक्रिय', child: Text('सक्रिय')),
                  DropdownMenuItem(value: 'पूर्ण जमा', child: Text('पूर्ण जमा')),
                ],
                onChanged: (v) => setLocal(() => status = v ?? status),
              ),
              const SizedBox(height: 10),
              tf(note, 'नोट'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('रद्द')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('सेव')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final newPrincipal = num0(pr.text);
      final newInterest = num0(ip.text);
      final newPrincipalPaid = num0(pp.text);

      l.borrower = name.text.trim().isEmpty ? l.borrower : name.text.trim();
      l.principal = newPrincipal > 0 ? newPrincipal : l.principal;
      l.rate = num0(rate.text);
      l.date = date;
      l.interestPaid = newInterest;
      l.principalPaid = newPrincipalPaid;
      l.status = status;
      l.note = note.text.trim();

      if (status == 'पूर्ण जमा') {
        l.repayDate ??= DateTime.now();
      } else {
        l.repayDate = null;
      }

      await s.save();
      if (mounted) {
        setState(() {});
        toast(context, 'एंट्री अपडेट हो गई');
      }
    }

    name.dispose();
    pr.dispose();
    rate.dispose();
    ip.dispose();
    pp.dispose();
    note.dispose();
  }

  Future<void> _delete(Loan l) async {
    if (!await confirm(context, '${l.borrower} की यह एंट्री हटाएँ?')) return;
    s.loans.remove(l);
    await s.save();
    if (mounted) {
      setState(() {});
      toast(context, 'एंट्री हटा दी गई');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = rows;
    final edit = s.canEdit;

    double totalPrincipal = 0;
    double totalPaid = 0;
    for (final item in list) {
      totalPrincipal += item.principal;
      totalPaid += (item.interestPaid + item.principalPaid);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('उधार खाता'),
        actions: [
          busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF शेयर',
                  onPressed: _pdf,
                ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 8, children: [
            for (final f in ['सभी', 'सक्रिय', 'पूर्ण जमा'])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('कोई एंट्री नहीं'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(C.primary),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      columnSpacing: 16,
                      columns: [
                        for (final h in [
                          'क्र.',
                          'नाम',
                          'मूलधन',
                          'दिनांक',
                          'ब्याज दर',
                          'ब्याज जमा',
                          'मूलधन जमा',
                          'कुल जमा',
                          'जमा दिनांक',
                          'स्थिति',
                          'नोट',
                        ])
                          DataColumn(label: Text(h)),
                        if (edit) const DataColumn(label: Text('कार्य')),
                      ],
                      rows: [
                        for (var i = 0; i < list.length; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(list[i].borrower)),
                            DataCell(Text(rs(list[i].principal))),
                            DataCell(Text(dt(list[i].date))),
                            DataCell(Text('${list[i].rate}%')),
                            DataCell(Text(rs(list[i].interestPaid))),
                            DataCell(Text(rs(list[i].principalPaid))),
                            DataCell(Text(rs(list[i].interestPaid + list[i].principalPaid))),
                            DataCell(Text(list[i].repayDate == null ? '-' : dt(list[i].repayDate!))),
                            DataCell(Text(
                              list[i].status,
                              style: TextStyle(
                                color: list[i].active ? C.accent : C.ok,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            DataCell(Text(list[i].note)),
                            if (edit)
                              DataCell(Row(children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: C.accent),
                                  onPressed: () => _edit(list[i]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: C.error),
                                  onPressed: () => _delete(list[i]),
                                ),
                              ])),
                          ]),
                      ],
                    ),
                  ),
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: C.surface,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('कुल मूलधन: ${rs(totalPrincipal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
              Text('कुल जमा: ${rs(totalPaid)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.primary)),
            ],
          ),
        ),
      ]),
    );
  }
}
