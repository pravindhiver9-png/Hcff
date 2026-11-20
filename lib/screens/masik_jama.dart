import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class _MonthKey {
  final int year;
  final int month;
  const _MonthKey(this.year, this.month);

  DateTime toDate() => DateTime(year, month, 1);

  String label() {
    const mNames = [
      'जनवरी', 'फरवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    return '${mNames[month - 1]} $year';
  }

  String shortLabel() {
    const mNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${mNames[month - 1]} $year';
  }

  @override
  bool operator ==(Object other) =>
      other is _MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

class MasikJamaScreen extends StatefulWidget {
  const MasikJamaScreen({super.key});
  @override
  State<MasikJamaScreen> createState() => _MasikJamaScreenState();
}

class _MasikJamaScreenState extends State<MasikJamaScreen> {
  final s = Store.I;

  DateTime jamaDate = DateTime.now();
  String? editingEntryId;

  // Har member ke liye selected months (Set<_MonthKey>) aur advance amount controller
  final Map<String, Set<_MonthKey>> _selectedMonths = {};
  final Map<String, TextEditingController> _advanceCtrls = {};

  String _lastWhatsappMsg = '';

  double get _fee => s.monthlyFee > 0 ? s.monthlyFee : 200.0;

  _MonthKey get _currentMonthKey => _MonthKey(jamaDate.year, jamaDate.month);

  @override
  void initState() {
    super.initState();
    _initMemberControllers();
  }

  void _initMemberControllers() {
    for (final m in s.members) {
      _selectedMonths.putIfAbsent(m.id, () => <_MonthKey>{});
      _advanceCtrls.putIfAbsent(m.id, () => TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _advanceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Member ke abhi tak ke total masik jama ke aadhar par kaun-kaun se mahine
  /// pichhle bakaya ya current mahine mein pending hain, ye nikalta hai.
  /// Rule: Jiska pichhle month ya kisi bhi pichhle month ka bakaya nahi hai,
  /// uske pichhle bakaya months ka checkbox nahi aayega.
  List<_MonthKey> _pendingMonthKeysForMember(String memberId) {
    final cur = _currentMonthKey;
    double totalPaid = 0;
    DateTime? earliestDate;

    for (final d in s.deposits) {
      if (d.memberId == memberId) {
        totalPaid += d.amount;
        final md = DateTime(d.monthDate.year, d.monthDate.month, 1);
        if (earliestDate == null || md.isBefore(earliestDate)) {
          earliestDate = md;
        }
      }
    }

    // Start month: agar pehle koi deposit record hai to us month se, warna current month se
    final start = earliestDate ?? DateTime(cur.year, cur.month, 1);
    final end = DateTime(cur.year, cur.month, 1);

    // Total months from start to current month inclusive
    final totalMonthsSpan =
        (end.year - start.year) * 12 + (end.month - start.month) + 1;
    final safeSpan = totalMonthsSpan < 1 ? 1 : totalMonthsSpan;

    final paidMonthsCount = (totalPaid / _fee).floor();

    final result = <_MonthKey>[];
    for (int i = 0; i < safeSpan; i++) {
      final dt = DateTime(start.year, start.month + i, 1);
      final key = _MonthKey(dt.year, dt.month);
      final isPast = dt.isBefore(end);

      // Agar mahina pehle hi pure fee se paid ho chuka hai to skip karein
      if (i < paidMonthsCount) continue;

      // Agar pichhla mahina hai aur bakaya nahi hai to nahi aayega;
      // bakaya hai to aayega, aur current mahina hamesha aayega
      if (isPast || key == cur) {
        result.add(key);
      }
    }

    if (result.isEmpty) {
      result.add(cur);
    }
    return result;
  }

  /// Advance amount se kitne next months auto paid honge
  List<_MonthKey> _autoNextMonthsFromAdvance(String memberId, double advAmt) {
    if (advAmt < _fee) return const [];
    final count = (advAmt / _fee).floor();

    // Unpaid months ke baad agle mahino se auto-paid
    final pending = _pendingMonthKeysForMember(memberId);
    final selected = _selectedMonths[memberId] ?? <_MonthKey>{};

    _MonthKey anchor = _currentMonthKey;
    final combined = <_MonthKey>{...pending, ...selected};
    if (combined.isNotEmpty) {
      final sorted = combined.toList()
        ..sort((a, b) => a.toDate().compareTo(b.toDate()));
      anchor = sorted.last;
    }

    final list = <_MonthKey>[];
    for (int i = 1; i <= count; i++) {
      final dt = DateTime(anchor.year, anchor.month + i, 1);
      list.add(_MonthKey(dt.year, dt.month));
    }
    return list;
  }

  double _memberTotalPaidForRow(Member m) {
    final selCount = (_selectedMonths[m.id]?.length ?? 0);
    final adv = num0(_advanceCtrls[m.id]?.text ?? '');
    return (selCount * _fee) + adv;
  }

  String _buildWhatsappText() {
    final lines = <String>[
      'दिनांक ${_fmtDate(jamaDate)}',
      '',
    ];

    for (final m in s.members) {
      final selCount = _selectedMonths[m.id]?.length ?? 0;
      final adv = num0(_advanceCtrls[m.id]?.text ?? '');
      final totalForMember = (selCount * _fee) + adv;

      if (totalForMember > 0) {
        final advNote = adv > 0 ? ' (एडवांस ₹${adv.toStringAsFixed(0)})' : '';
        lines.add('${m.name} ₹${totalForMember.toStringAsFixed(0)} जमा$advNote');
      }
    }

    return lines.join('\n').trim();
  }

  Future<void> _openWhatsapp(String text) async {
    if (text.trim().isEmpty) return toast(context, 'मैसेज खाली है');
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: text));
        toast(context, 'WhatsApp नहीं खुल सका — मैसेज कॉपी हो गया');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) toast(context, 'मैसेज कॉपी कर लिया गया है');
    }
  }

  Future<void> _showWhatsappDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp मैसेज'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) toast(context, 'मैसेज कॉपी हो गया');
            },
            child: const Text('कॉपी'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openWhatsapp(text);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('WhatsApp भेजें'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickJamaDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: jamaDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => jamaDate = picked);
    }
  }

  Future<void> _saveAll() async {
    _initMemberControllers();
    bool anySaved = false;

    for (final m in s.members) {
      final selSet = _selectedMonths[m.id] ?? <_MonthKey>{};
      final adv = num0(_advanceCtrls[m.id]?.text ?? '');

      // Selected months ke liye entries
      for (final mk in selSet) {
        s.deposits.add(
          MonthlyDeposit(
            id: s.newId(),
            memberId: m.id,
            monthDate: mk.toDate(),
            date: jamaDate,
            amount: _fee,
            note: 'मासिक जमा (${mk.shortLabel()})',
          ),
        );
        anySaved = true;
      }

      // Advance amount ke liye entry + next months auto-paid note
      if (adv > 0) {
        final nextAuto = _autoNextMonthsFromAdvance(m.id, adv);
        final autoText = nextAuto.isEmpty
            ? 'एडवांस जमा'
            : 'एडवांस जमा — स्वतः अगले माह पेड: ${nextAuto.map((e) => e.shortLabel()).join(', ')}';

        s.deposits.add(
          MonthlyDeposit(
            id: s.newId(),
            memberId: m.id,
            monthDate: _currentMonthKey.toDate(),
            date: jamaDate,
            amount: adv,
            note: autoText,
          ),
        );
        anySaved = true;
      }
    }

    if (!anySaved) {
      return toast(context, 'कम से कम एक सदस्य का महीना या एडवांस राशि भरें');
    }

    final msg = _buildWhatsappText();
    await s.save();
    if (!mounted) return;

    toast(context, 'मासिक जमा सेव हो गई');
    setState(() {
      _lastWhatsappMsg = msg;
      editingEntryId = null;
      for (final set in _selectedMonths.values) {
        set.clear();
      }
      for (final c in _advanceCtrls.values) {
        c.clear();
      }
    });

    await _showWhatsappDialog(msg);
  }

  Future<void> _editDepositEntry(MonthlyDeposit entry) async {
    final amtCtrl = TextEditingController(text: entry.amount.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: entry.note);
    var dDate = entry.date;
    var mDate = entry.monthDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${s.memberById(entry.memberId)?.name ?? 'सदस्य'} — एंट्री बदलें'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tf(amtCtrl, 'राशि (₹)', number: true),
                DateField(
                  label: 'माह तारीख',
                  value: mDate,
                  onChanged: (d) => setLocal(() => mDate = d),
                ),
                DateField(
                  label: 'जमा दिनांक',
                  value: dDate,
                  onChanged: (d) => setLocal(() => dDate = d),
                ),
                tf(noteCtrl, 'नोट'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('सेव')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final newAmt = num0(amtCtrl.text);
      if (newAmt > 0) {
        entry.amount = newAmt;
      }
      entry.monthDate = mDate;
      entry.date = dDate;
      entry.note = noteCtrl.text.trim();
      await s.save();
      if (mounted) {
        setState(() {});
        toast(context, 'एंट्री अपडेट हो गई');
      }
    }

    amtCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _deleteDepositEntry(MonthlyDeposit entry) async {
    final mName = s.memberById(entry.memberId)?.name ?? 'सदस्य';
    if (!await confirm(context, '$mName (${rs(entry.amount)}) की एंट्री हटाएँ?')) return;
    s.deposits.remove(entry);
    await s.save();
    if (mounted) {
      setState(() {});
      toast(context, 'एंट्री हटा दी गई');
    }
  }

  @override
  Widget build(BuildContext context) {
    _initMemberControllers();

    final depositsList = List<MonthlyDeposit>.from(s.deposits)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('मासिक जमा'),
        actions: [
          if (_lastWhatsappMsg.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'WhatsApp मैसेज देखें',
              onPressed: () => _showWhatsappDialog(_lastWhatsappMsg),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- 1. जमा दिनांक ----
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'जमा दिनांक',
                        style: TextStyle(fontSize: 12, color: C.text2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtDate(jamaDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickJamaDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('दिनांक बदलें'),
                ),
              ],
            ),
          ),

          // ---- 2. सभी सदस्यों की सूची + चेकबॉक्स + एडवांस बॉक्स ----
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'सदस्य सूची (बकाया / वर्तमान माह व एडवांस)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text),
            ),
          ),

          for (final m in s.members) ...[
            Builder(
              builder: (context) {
                final keys = _pendingMonthKeysForMember(m.id);
                final selSet = _selectedMonths[m.id]!;
                final advCtrl = _advanceCtrls[m.id]!;
                final advAmt = num0(advCtrl.text);
                final autoNext = _autoNextMonthsFromAdvance(m.id, advAmt);
                final rowTotal = _memberTotalPaidForRow(m);

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text),
                            ),
                          ),
                          Text(
                            rs(rowTotal),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: C.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Checkboxes (केवल बकाया / वर्तमान माह के लिए)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final mk in keys)
                            FilterChip(
                              label: Text('${mk.shortLabel()} (${rs(_fee)})'),
                              selected: selSet.contains(mk),
                              onSelected: (checked) {
                                setState(() {
                                  if (checked) {
                                    selSet.add(mk);
                                  } else {
                                    selSet.remove(mk);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Advance Text Box
                      TextFormField(
                        controller: advCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'एडवांस राशि (₹) — अगले माह में स्वतः पेड',
                          hintText: '0',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      if (autoNext.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'स्वतः अगले माह पेड: ${autoNext.map((e) => e.shortLabel()).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: C.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 6),
          btn('जमा सेव करें व WhatsApp मैसेज बनाएँ', _saveAll, icon: Icons.save),

          if (_lastWhatsappMsg.isNotEmpty) ...[
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'तैयार WhatsApp मैसेज',
                    style: TextStyle(fontWeight: FontWeight.bold, color: C.primary),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(_lastWhatsappMsg),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _lastWhatsappMsg));
                          if (mounted) toast(context, 'मैसेज कॉपी हो गया');
                        },
                        child: const Text('कॉपी'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openWhatsapp(_lastWhatsappMsg),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ---- 3. मासिक जमा सूची (Edit & Delete) ----
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              'मासिक जमा सूची',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text),
            ),
          ),

          if (depositsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('अभी कोई जमा एंट्री नहीं है', style: TextStyle(color: C.text2)),
            )
          else
            for (final entry in depositsList)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.memberById(entry.memberId)?.name ?? 'सदस्य'}  •  ${rs(entry.amount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: C.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'दिनांक: ${_fmtDate(entry.date)}  •  माह: ${_MonthKey(entry.monthDate.year, entry.monthDate.month).shortLabel()}',
                            style: const TextStyle(fontSize: 12, color: C.text2),
                          ),
                          if (entry.note.isNotEmpty)
                            Text(
                              entry.note,
                              style: const TextStyle(fontSize: 12, color: C.primary),
                            ),
                        ],
                      ),
                    ),
                    if (s.canEdit) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: C.accent),
                        onPressed: () => _editDepositEntry(entry),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: C.error),
                        onPressed: () => _deleteDepositEntry(entry),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
