import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class KharchAtiriktScreen extends StatelessWidget {
  final int initialTab;
  const KharchAtiriktScreen({super.key, this.initialTab = 0});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        initialIndex: initialTab,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('खर्च और अतिरिक्त राशि'),
            bottom: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.white, tabs: [Tab(text: 'खर्च'), Tab(text: 'अतिरिक्त राशि')]),
          ),
          body: const TabBarView(children: [_EntryTab(isKharch: true), _EntryTab(isKharch: false)]),
        ),
      );
}

class _EntryTab extends StatefulWidget {
  final bool isKharch;
  const _EntryTab({required this.isKharch});
  @override
  State<_EntryTab> createState() => _EntryTabState();
}

class _EntryTabState extends State<_EntryTab> {
  final s = Store.I;
  final amount = TextEditingController(), note = TextEditingController();
  DateTime date = DateTime.now();

  List<MoneyEntry> get list => widget.isKharch ? s.kharch : s.atirikt;

  Future<void> _save() async {
    final a = num0(amount.text);
    if (a <= 0) return toast(context, 'सही राशि लिखें');
    list.add(MoneyEntry(id: s.newId(), amount: a, date: date, note: note.text.trim()));
    await s.save();
    if (!mounted) return;
    setState(() {
      amount.clear();
      note.clear();
    });
    toast(context, 'दर्ज हो गया');
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...list]..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold(0.0, (a, e) => a + e.amount);
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (s.canEdit)
        AppCard(child: Column(children: [
          tf(amount, widget.isKharch ? 'खर्च राशि (₹)' : 'अतिरिक्त राशि (₹) — आय / जुर्माना / अन्य', number: true),
          tf(note, widget.isKharch ? 'खर्च का विवरण' : 'विवरण'),
          DateField(label: 'दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
          btn('सेव करें', _save, icon: Icons.save),
        ])),
      Text('कुल: ${rs(total)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
      const SizedBox(height: 8),
      for (final e in sorted)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(child: Text('${e.note.isEmpty ? (widget.isKharch ? 'खर्च' : 'अतिरिक्त') : e.note}\n${dt(e.date)}', style: const TextStyle(color: C.text))),
            Text(rs(e.amount), style: TextStyle(fontWeight: FontWeight.bold, color: widget.isKharch ? C.error : C.ok)),
            if (s.canEdit)
              IconButton(
                icon: const Icon(Icons.delete, color: C.error),
                onPressed: () async {
                  if (await confirm(context, 'यह एंट्री हटाएँ?')) {
                    list.remove(e);
                    await s.save();
                    if (mounted) setState(() {});
                  }
                },
              ),
          ]),
        ),
    ]);
  }
}
