import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  DateTime jamaDate = DateTime.now();

  final Map<String, Set<String>> _selectedMonthKeys = {};
  final Map<String, TextEditingController> _advanceCtrls = {};

  String _lastWhatsappMsg = '';

  double get _perMonth => s.monthlyAmount > 0 ? s.monthlyAmount : 200.0;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    for (final m in s.members) {
      _selectedMonthKeys.putIfAbsent(m.id, () => <String>{});
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

  String _label(String key) {
    final p = key.split('-');
    return DateFormat('MMM yyyy').format(DateTime(int.parse(p[0]), int.parse(p[1]), 1));
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// केवल पिछले बकाया महीने (यदि कोई बकाया है) और वर्तमान महीना लौटाता है।
  /// जिस सदस्य का पिछले किसी भी महीने का बकाया नहीं है, उसके पिछले महीनों का चेकबॉक्स नहीं आएगा।
  List<String> _applicableMonthKeys(String memberId) {
    final paid = s.fe.paidMonths(memberId);
    final curMonthStart = DateTime(jamaDate.year, jamaDate.month, 1);
    final curKey = FinanceEngine.monthKey(curMonthStart);

    DateTime? earliest;
    for (final j in s.jama) {
      if (j.memberId == memberId) {
        final parts = j.month.split('-');
        if (parts.length == 2) {
          final jd = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
          if (earliest == null || jd.isBefore(earliest)) {
            earliest = jd;
          }
        }
      }
    }

    final start = earliest ?? curMonthStart;
    final keys = <String>[];
    var cursor = DateTime(start.year, start.month, 1);

    while (!cursor.isAfter(curMonthStart)) {
      final k = FinanceEngine.monthKey(cursor);
      final isPast = cursor.isBefore(curMonthStart);

      if (isPast) {
        if (!paid.contains(k)) {
          keys.add(k);
        }
      } else {
        keys.add(k);
      }
      cursor = FinanceEngine.addMonths(cursor, 1);
    }

    if (!keys.contains(curKey)) {
      keys.add(curKey);
    }
    return keys;
  }

  /// एडवांस राशि से कितने अगले महीने स्वतः पेड होंगे
  List<String> _autoAdvanceMonths(String memberId, double advAmt) {
    if (advAmt <= 0) return const [];
    var n = (advAmt / _perMonth).floor();
    if (n < 1) n = 1;

    final paid = s.fe.paidMonths(memberId);
    final selected = _selectedMonthKeys[memberId] ?? <String>{};
    paid.addAll(selected);

    var cur = DateTime(jamaDate.year, jamaDate.month, 1);
    while (paid.contains(FinanceEngine.monthKey(cur))) {
      cur = FinanceEngine.addMonths(cur, 1);
    }

    final months = <String>[];
    for (var k = 0; k < n; k++) {
      while (paid.contains(FinanceEngine.monthKey(cur))) {
        cur = FinanceEngine.addMonths(cur, 1);
      }
      final mk = FinanceEngine.monthKey(cur);
      months.add(mk);
      paid.add(mk);
      cur = FinanceEngine.addMonths(cur, 1);
    }
    return months;
  }

  double _memberSelectedTotal(Member m) {
    final selCount = _selectedMonthKeys[m.id]?.length ?? 0;
    final adv = num0(_advanceCtrls[m.id]?.text ?? '');
    return (selCount * _perMonth) + adv;
  }

  String _formatRsClean(double v) =>
      v == v.roundToDouble() ? '₹${v.toInt()}' : '₹${v.toStringAsFixed(2)}';

  String _buildWhatsappMessage() {
    final lines = <String>[
      'दिनांक ${_fmtDate(jamaDate)}',
      '',
    ];

    for (final m in s.members) {
      final total = _memberSelectedTotal(m);
      if (total > 0) {
        lines.add('${m.name} ${_formatRsClean(total)} जमा');
      }
    }

    return lines.join('\n').trim();
  }

  Future<void> _openWhatsapp(String msg) async {
    if (msg.trim().isEmpty) return toast(context, 'मैसेज खाली है');
    final encoded = Uri.encodeComponent(msg);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: msg));
        toast(context, 'WhatsApp नहीं खुल सका — मैसेज कॉपी हो गया');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) toast(context, 'मैसेज कॉपी कर लिया गया है');
    }
  }

  Future<void> _showWhatsappDialog(String msg) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp मैसेज'),
        content: SingleChildScrollView(child: SelectableText(msg)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: msg));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) toast(context, 'मैसेज कॉपी हो गया');
            },
            child: const Text('कॉपी'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openWhatsapp(msg);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('WhatsApp भेजें'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    _syncControllers();
    final msg = _buildWhatsappMessage();
    bool savedAny = false;

    for (final m in s.members) {
      final selSet = _selectedMonthKeys[m.id] ?? <String>{};
      final adv = num0(_advanceCtrls[m.id]?.text ?? '');
      final paid = s.fe.paidMonths(m.id);

      for (final mk in selSet) {
        s.jama.add(MasikJama(
          id: s.newId(),
          memberId: m.id,
          month: mk,
          amount: _perMonth,
          date: jamaDate,
        ));
        paid.add(mk);
        savedAny = true;
      }

      if (adv > 0) {
        var n = (adv / _perMonth).floor();
        if (n < 1) n = 1;
        var cur = DateTime(jamaDate.year, jamaDate.month, 1);
        while (paid.contains(FinanceEngine.monthKey(cur))) {
          cur = FinanceEngine.addMonths(cur, 1);
        }
        var left = adv;
        for (var k = 0; k < n; k++) {
          while (paid.contains(FinanceEngine.monthKey(cur))) {
            cur = FinanceEngine.addMonths(cur, 1);
          }
          final a = (k == n - 1) ? left : _perMonth;
          final mk = FinanceEngine.monthKey(cur);
          s.jama.add(MasikJama(
            id: s.newId(),
            memberId: m.id,
            month: mk,
            amount: a,
            date: jamaDate,
          ));
          paid.add(mk);
          left -= a;
          cur = FinanceEngine.addMonths(cur, 1);
          savedAny = true;
        }
      }
    }

    if (!savedAny) {
      return toast(context, 'कम से कम एक सदस्य का महीना या एडवांस राशि भरें');
    }

    await s.save();
    if (!mounted) return;

    toast(context, 'मासिक जमा सेव हो गई');
    setState(() {
      _lastWhatsappMsg = msg;
      for (final set in _selectedMonthKeys.values) {
        set.clear();
      }
      for (final c in _advanceCtrls.values) {
        c.clear();
      }
    });

    await _showWhatsappDialog(msg);
  }

  Future<void> _editJama(MasikJama j) async {
    final amtCtrl = TextEditingController(text: j.amount.toStringAsFixed(0));
    var dDate = j.date;
    final parts = j.month.split('-');
    var mDate = parts.length == 2
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), 1)
        : DateTime(jamaDate.year, jamaDate.month, 1);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${s.memberById(j.memberId)?.name ?? 'सदस्य'} — जमा बदलें'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tf(amtCtrl, 'राशि (₹)', number: true),
                DateField(
                  label: 'माह (कोई भी तारीख़ चुनें)',
                  value: mDate,
                  onChanged: (d) => setLocal(() => mDate = DateTime(d.year, d.month, 1)),
                ),
                DateField(
                  label: 'जमा दिनांक',
                  value: dDate,
                  onChanged: (d) => setLocal(() => dDate = d),
                ),
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
      if (newAmt > 0) j.amount = newAmt;
      j.month = FinanceEngine.monthKey(mDate);
      j.date = dDate;
      await s.save();
      if (mounted) {
        setState(() {});
        toast(context, 'जमा एंट्री अपडेट हो गई');
      }
    }

    amtCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();
    final fe = s.fe;
    final recent = [...s.jama]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('मासिक जमा'),
        actions: [
          if (_lastWhatsappMsg.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'WhatsApp मैसेज',
              onPressed: () => _showWhatsappDialog(_lastWhatsappMsg),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (s.canEdit) ...[
            AppCard(
              child: DateField(
                label: 'जमा दिनांक',
                value: jamaDate,
                onChanged: (d) => setState(() => jamaDate = d),
              ),
            ),
            sectionTitle('सदस्य सूची'),
            for (final m in s.members)
              Builder(
                builder: (context) {
                  final keys = _applicableMonthKeys(m.id);
                  final selSet = _selectedMonthKeys[m.id]!;
                  final advCtrl = _advanceCtrls[m.id]!;
                  final advAmt = num0(advCtrl.text);
                  final autoNext = _autoAdvanceMonths(m.id, advAmt);
                  final rowTotal = _memberSelectedTotal(m);

                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.text),
                              ),
                            ),
                            Text(
                              rs(rowTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final mk in keys)
                              FilterChip(
                                label: Text('${_label(mk)} (${rs(_perMonth)})'),
                                selected: selSet.contains(mk),
                                onSelected: (on) {
                                  setState(() {
                                    if (on) {
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
                        TextFormField(
                          controller: advCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'एडवांस राशि (₹) — स्वतः अगले माह में जुड़ेगा',
                            hintText: '0',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (autoNext.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'स्वतः अगले माह पेड: ${autoNext.map(_label).join(', ')}',
                            style: const TextStyle(fontSize: 12, color: C.ok, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
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
                          label: const Text('WhatsApp भेजें'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
          sectionTitle('सदस्यवार स्थिति'),
          for (final m in s.members)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                        Text(
                          'अंतिम जमा महीना: ${fe.lastPaidMonth(m.id) == null ? '-' : _label(fe.lastPaidMonth(m.id)!)}',
                          style: const TextStyle(fontSize: 12, color: C.text2),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rs(fe.memberJama(m.id)), style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                      if (fe.advanceMonths(m.id) > 0)
                        Text('एडवांस ${fe.advanceMonths(m.id)} माह', style: const TextStyle(fontSize: 12, color: C.ok)),
                    ],
                  ),
                ],
              ),
            ),
          sectionTitle('जमा रजिस्टर'),
          for (final j in recent)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.memberById(j.memberId)?.name ?? ''} • ${_label(j.month)}\n${dt(j.date)}',
                      style: const TextStyle(color: C.text),
                    ),
                  ),
                  Text(rs(j.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: C.ok)),
                  if (s.canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, color: C.accent),
                      onPressed: () => _editJama(j),
                    ),
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
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
