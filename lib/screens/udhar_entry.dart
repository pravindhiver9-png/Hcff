import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _editingLoanId;

  final name = TextEditingController(),
      mobile = TextEditingController(),
      amount = TextEditingController(),
      note = TextEditingController();
  late final rate = TextEditingController(text: s.memberRate.toString());
  DateTime date = DateTime.now();

  String _lastMsg = '';
  String _lastPhone = '';

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    amount.dispose();
    note.dispose();
    rate.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _cleanMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return digits.substring(2);
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  String _buildMessage({
    required String who,
    required String phone,
    required double amt,
    required double r,
    required DateTime dt,
    required String remark,
  }) {
    final b = StringBuffer()
      ..writeln('*$kGroupName*')
      ..writeln('उधार विवरण')
      ..writeln('----------------')
      ..writeln('नाम: $who')
      ..writeln('मूलधन: ${rs(amt)}')
      ..writeln('ब्याज दर: $r% प्रति माह')
      ..writeln('दिनांक: ${_fmtDate(dt)}');
    if (phone.isNotEmpty) b.writeln('मोबाइल: +91 $phone');
    if (remark.isNotEmpty) b.writeln('नोट: $remark');
    return b.toString().trim();
  }

  Future<void> _sendWhatsapp(String msg, String rawPhone) async {
    if (msg.trim().isEmpty) return;
    final p = _cleanMobile(rawPhone);
    final encoded = Uri.encodeComponent(msg);
    final uri = p.length == 10
        ? Uri.parse('https://wa.me/91$p?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await Clipboard.setData(ClipboardData(text: msg));
        toast(context, 'WhatsApp नहीं खुल सका — मैसेज कॉपी हो गया');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) toast(context, 'मैसेज क्लिपबोर्ड में कॉपी कर लिया गया है');
    }
  }

  void _startEditingEntry({
    required String loanId,
    required bool isOutsider,
    required String? mId,
    required String borrowerName,
    required String phone,
    required double amt,
    required double rVal,
    required DateTime dt,
    required String remark,
  }) {
    setState(() {
      _editingLoanId = loanId;
      outsider = isOutsider;
      memberId = isOutsider ? null : mId;
      name.text = isOutsider ? borrowerName : '';
      mobile.text = phone;
      amount.text = amt.toString();
      rate.text = rVal.toString();
      date = dt;
      note.text = remark;
    });
    toast(context, 'एंट्री सुधारने के लिए फॉर्म में लोड हो गई है');
  }

  void _cancelEditing() {
    setState(() {
      _editingLoanId = null;
      amount.clear();
      note.clear();
      name.clear();
      mobile.clear();
      rate.text = (outsider ? s.outsiderRate : s.memberRate).toString();
    });
  }

  Future<void> _showMsgDialog({
    required String msg,
    required String rawPhone,
    required String loanId,
    required bool isOutsider,
    required String? mId,
    required String borrowerName,
    required double amt,
    required double rVal,
    required DateTime dt,
    required String remark,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp मैसेज प्रीव्यू'),
        content: SingleChildScrollView(child: SelectableText(msg)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startEditingEntry(
                loanId: loanId,
                isOutsider: isOutsider,
                mId: mId,
                borrowerName: borrowerName,
                phone: rawPhone,
                amt: amt,
                rVal: rVal,
                dt: dt,
                remark: remark,
              );
            },
            child: const Text('एंट्री सुधारें'),
          ),
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
              await _sendWhatsapp(msg, rawPhone);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('WhatsApp भेजें'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amt = num0(amount.text);
    final mObj = s.memberById(memberId);
    final who = outsider ? name.text.trim() : (mObj?.name ?? '');
    final phone = _cleanMobile(mobile.text.trim());
    final rVal = num0(rate.text);
    final nVal = note.text.trim();

    if (who.isEmpty) return toast(context, outsider ? 'नाम लिखें' : 'सदस्य चुनें');
    if (amt <= 0) return toast(context, 'सही राशि लिखें');

    final existingIdx =
        _editingLoanId == null ? -1 : s.loans.indexWhere((l) => l.id == _editingLoanId);
    final oldPrincipal = existingIdx >= 0 ? s.loans[existingIdx].principal : 0.0;
    final netExtraNeeded = amt - oldPrincipal;

    if (netExtraNeeded > s.fe.totalFund &&
        !await confirm(context, 'उधार राशि कुल फंड (${rs(s.fe.totalFund)}) से ज़्यादा है। फिर भी सेव करें?')) {
      return;
    }

    final loanId = existingIdx >= 0 ? s.loans[existingIdx].id : s.newId();
    final updatedLoan = Loan(
      id: loanId,
      memberId: outsider ? null : memberId,
      borrower: who,
      principal: amt,
      date: date,
      rate: rVal,
      note: nVal,
    );

    if (existingIdx >= 0) {
      s.loans[existingIdx] = updatedLoan;
    } else {
      s.loans.add(updatedLoan);
    }

    await s.save();
    if (!mounted) return;

    final generated = _buildMessage(
      who: who,
      phone: phone,
      amt: amt,
      r: rVal,
      dt: date,
      remark: nVal,
    );

    toast(context, existingIdx >= 0 ? 'उधार एंट्री अपडेट हो गई' : 'उधार दर्ज हो गया');
    setState(() {
      _lastMsg = generated;
      _lastPhone = phone;
      _editingLoanId = null;
      amount.clear();
      note.clear();
      name.clear();
      mobile.clear();
    });

    await _showMsgDialog(
      msg: generated,
      rawPhone: phone,
      loanId: loanId,
      isOutsider: outsider,
      mId: memberId,
      borrowerName: who,
      amt: amt,
      rVal: rVal,
      dt: date,
      remark: nVal,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('उधार एंट्री')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(
            child: Column(children: [
              if (_editingLoanId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'पुरानी एंट्री सुधारी जा रही है',
                          style: TextStyle(fontWeight: FontWeight.bold, color: C.primary),
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelEditing,
                        child: const Text('रद्द करें'),
                      ),
                    ],
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('बाहरी व्यक्ति (सदस्य नहीं)'),
                value: outsider,
                onChanged: (v) => setState(() {
                  outsider = v;
                  rate.text = (v ? s.outsiderRate : s.memberRate).toString();
                  if (!v && memberId != null) {
                    mobile.text = s.memberById(memberId)?.mobile ?? '';
                  }
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
                    items: [
                      for (final m in s.members)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: (v) => setState(() {
                      memberId = v;
                      mobile.text = s.memberById(v)?.mobile ?? '';
                    }),
                  ),
                ),
              tf(mobile, 'मोबाइल नंबर (WhatsApp)', number: true),
              tf(amount, 'मूलधन (₹)', number: true),
              tf(rate, 'ब्याज दर (% प्रति माह)', number: true),
              DateField(label: 'दिनांक', value: date, onChanged: (d) => setState(() => date = d)),
              tf(note, 'नोट (वैकल्पिक)'),
              btn(
                _editingLoanId != null ? 'सुधार सेव करें' : 'उधार सेव करें',
                _save,
                icon: Icons.save,
              ),
            ]),
          ),
          Text('उपलब्ध फंड: ${rs(s.fe.totalFund)}', style: const TextStyle(color: C.text2)),
          if (_lastMsg.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _sendWhatsapp(_lastMsg, _lastPhone),
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp मैसेज भेजें'),
            ),
          ],
        ]),
      );
}
