import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class JamaWapsiScreen extends StatefulWidget {
  const JamaWapsiScreen({super.key});
  @override
  State<JamaWapsiScreen> createState() => _JamaWapsiScreenState();
}

class _JamaWapsiScreenState extends State<JamaWapsiScreen> {
  final s = Store.I;

  String? selectedBorrower;
  String? selectedLoanId;
  String? _editingLoanId;

  DateTime repayDate = DateTime.now();
  final dateTextCtrl = TextEditingController();
  final finalInterestCtrl = TextEditingController();
  final interestPaidCtrl = TextEditingController();
  final principalPaidCtrl = TextEditingController();

  String _lastMsg = '';
  String _lastPhone = '';

  List<Loan> get _activeLoans => s.loans.where((l) => l.active).toList();

  List<String> get _borrowerNames {
    final set = <String>{};
    for (final l in _activeLoans) {
      if (l.borrower.trim().isNotEmpty) set.add(l.borrower.trim());
    }
    return set.toList();
  }

  List<Loan> get _loansForBorrower {
    if (selectedBorrower == null) return const [];
    final list = _activeLoans.where((l) => l.borrower.trim() == selectedBorrower).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Loan? get _selectedLoan {
    final loans = _loansForBorrower;
    if (loans.isEmpty) return null;
    if (selectedLoanId != null) {
      for (final l in loans) {
        if (l.id == selectedLoanId) return l;
      }
    }
    return loans.first;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parseTypedDate(String raw) {
    final clean = raw.trim().replaceAll('-', '/').replaceAll('.', '/');
    final parts = clean.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  void _syncInitialSelection() {
    final names = _borrowerNames;
    if (names.isNotEmpty) {
      if (selectedBorrower == null || !names.contains(selectedBorrower)) {
        selectedBorrower = names.first;
      }
      final loans = _loansForBorrower;
      if (loans.isNotEmpty && (selectedLoanId == null || !loans.any((l) => l.id == selectedLoanId))) {
        selectedLoanId = loans.first.id;
      }
    } else {
      selectedBorrower = null;
      selectedLoanId = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncInitialSelection();
    dateTextCtrl.text = _fmtDate(repayDate);

    finalInterestCtrl.addListener(_onFieldChange);
    interestPaidCtrl.addListener(_onFieldChange);
    principalPaidCtrl.addListener(_onFieldChange);
    dateTextCtrl.addListener(_onDateTextChange);
  }

  void _onFieldChange() {
    if (mounted) setState(() {});
  }

  void _onDateTextChange() {
    final parsed = _parseTypedDate(dateTextCtrl.text);
    if (parsed != null && parsed != repayDate) {
      repayDate = parsed;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    finalInterestCtrl.removeListener(_onFieldChange);
    interestPaidCtrl.removeListener(_onFieldChange);
    principalPaidCtrl.removeListener(_onFieldChange);
    dateTextCtrl.removeListener(_onDateTextChange);

    dateTextCtrl.dispose();
    finalInterestCtrl.dispose();
    interestPaidCtrl.dispose();
    principalPaidCtrl.dispose();
    super.dispose();
  }

  int _daysDiff(Loan l) {
    final diff = repayDate.difference(l.date).inDays;
    return diff < 0 ? 0 : diff;
  }

  double _monthsApprox(Loan l) {
    final days = _daysDiff(l);
    return days / 30.0;
  }

  String _formatPeriod(Loan l) {
    final days = _daysDiff(l);
    final months = (days / 30).floor();
    final remDays = days % 30;
    if (months <= 0) return '$days दिन';
    if (remDays == 0) return '$months माह ($days दिन)';
    return '$months माह $remDays दिन ($days दिन)';
  }

  double _remainingPrincipal(Loan? l) {
    if (l == null) return 0.0;
    final rem = l.principal - l.principalPaid;
    return rem < 0 ? 0.0 : rem;
  }

  double _expectedInterest(Loan? l) {
    if (l == null) return 0.0;
    final rem = _remainingPrincipal(l);
    final months = _monthsApprox(l);
    return rem * (l.rate / 100.0) * months;
  }

  double get _typedInterestPaid => num0(interestPaidCtrl.text);
  double get _typedPrincipalPaid => num0(principalPaidCtrl.text);
  double get _totalDeposit => _typedInterestPaid + _typedPrincipalPaid;

  String _autoStatus(Loan? l) {
    if (l == null) return 'सक्रिय';
    final rem = _remainingPrincipal(l);
    if (_typedPrincipalPaid >= rem && rem > 0) return 'पूर्ण जमा';
    if (l.principalPaid + _typedPrincipalPaid >= l.principal) return 'पूर्ण जमा';
    return 'सक्रिय';
  }

  String _cleanMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) return digits.substring(2);
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  String _extractPhoneFromNote(String n) {
    final match = RegExp(r'(?:\+91[\s-]*)?([6-9]\d{9})').firstMatch(n);
    return match?.group(1) ?? '';
  }

  String _buildWhatsappMessage({
    required Loan loan,
    required double finalInt,
    required double intPaid,
    required double priPaid,
    required double totalPaid,
    required String statusText,
    required DateTime dt,
  }) {
    final remAfter = (_remainingPrincipal(loan) - priPaid).clamp(0.0, double.infinity);
    final b = StringBuffer()
      ..writeln('*$kGroupName*')
      ..writeln('जमा वापसी रसीद')
      ..writeln('----------------')
      ..writeln('नाम: ${loan.borrower}')
      ..writeln('उधार दिनांक: ${_fmtDate(loan.date)}')
      ..writeln('जमा दिनांक: ${_fmtDate(dt)}')
      ..writeln('मूलधन: ${rs(loan.principal)}')
      ..writeln('ब्याज दर: ${loan.rate}% प्रति माह')
      ..writeln('अवधि: ${_formatPeriod(loan)}')
      ..writeln('संभावित ब्याज: ${rs(_expectedInterest(loan))}');
    if (finalInt > 0) b.writeln('अंतिम ब्याज: ${rs(finalInt)}');
    b
      ..writeln('ब्याज जमा: ${rs(intPaid)}')
      ..writeln('मूलधन जमा: ${rs(priPaid)}')
      ..writeln('कुल जमा राशि: ${rs(totalPaid)}')
      ..writeln('शेष मूलधन: ${rs(remAfter)}')
      ..writeln('स्थिति: $statusText');
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

  Future<void> _pickCalendarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: repayDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        repayDate = picked;
        dateTextCtrl.text = _fmtDate(picked);
      });
    }
  }

  void _editFromPreview(Loan loan, double finalInt, double intPaid, double priPaid, DateTime dt) {
    setState(() {
      _editingLoanId = loan.id;
      selectedBorrower = loan.borrower;
      selectedLoanId = loan.id;
      repayDate = dt;
      dateTextCtrl.text = _fmtDate(dt);
      finalInterestCtrl.text = finalInt > 0 ? finalInt.toStringAsFixed(0) : '';
      interestPaidCtrl.text = intPaid > 0 ? intPaid.toStringAsFixed(0) : '';
      principalPaidCtrl.text = priPaid > 0 ? priPaid.toStringAsFixed(0) : '';
    });
    toast(context, 'एंट्री सुधारने के लिए फॉर्म में खुल गई है');
  }

  Future<void> _showPreviewDialog({
    required String msg,
    required String phone,
    required Loan loan,
    required double finalInt,
    required double intPaid,
    required double priPaid,
    required DateTime dt,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('जमा प्रीव्यू (WhatsApp मैसेज)'),
        content: SingleChildScrollView(child: SelectableText(msg)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _editFromPreview(loan, finalInt, intPaid, priPaid, dt);
            },
            child: const Text('एडिट करें'),
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
              await _sendWhatsapp(msg, phone);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('WhatsApp भेजें'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final targetId = _editingLoanId ?? _selectedLoan?.id;
    if (targetId == null) return toast(context, 'सक्रिय उधार चुनें');

    final idx = s.loans.indexWhere((x) => x.id == targetId);
    if (idx < 0) return toast(context, 'उधार रिकॉर्ड नहीं मिला');
    final loan = s.loans[idx];

    final parsedDate = _parseTypedDate(dateTextCtrl.text) ?? repayDate;
    repayDate = parsedDate;
    dateTextCtrl.text = _fmtDate(parsedDate);

    final finalInt = num0(finalInterestCtrl.text);
    final intPaid = _typedInterestPaid;
    final priPaid = _typedPrincipalPaid;
    final totalPaid = intPaid + priPaid;

    if (totalPaid <= 0) {
      return toast(context, 'ब्याज जमा या मूलधन जमा राशि लिखें');
    }

    loan.interestPaid = loan.interestPaid + intPaid;
    loan.principalPaid = loan.principalPaid + priPaid;
    loan.repayDate = parsedDate;

    final isFull = loan.principalPaid >= loan.principal;
    final statusText = isFull ? 'पूर्ण जमा' : 'सक्रिय';
    loan.status = statusText;

    if (finalInt > 0) {
      final tag = 'अंतिम ब्याज: ${rs(finalInt)}';
      if (!loan.note.contains(tag)) {
        loan.note = loan.note.isEmpty ? tag : '${loan.note} | $tag';
      }
    }

    await s.save();
    if (!mounted) return;

    final msg = _buildWhatsappMessage(
      loan: loan,
      finalInt: finalInt,
      intPaid: intPaid,
      priPaid: priPaid,
      totalPaid: totalPaid,
      statusText: statusText,
      dt: parsedDate,
    );
    final phone = _extractPhoneFromNote(loan.note);

    toast(context, 'जमा सेव हो गई ($statusText)');

    setState(() {
      _lastMsg = msg;
      _lastPhone = phone;
      _editingLoanId = null;
      finalInterestCtrl.clear();
      interestPaidCtrl.clear();
      principalPaidCtrl.clear();
      _syncInitialSelection();
    });

    await _showPreviewDialog(
      msg: msg,
      phone: phone,
      loan: loan,
      finalInt: finalInt,
      intPaid: intPaid,
      priPaid: priPaid,
      dt: parsedDate,
    );
  }

  Widget _highlightedCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.primary, width: 1.6),
      ),
      child: child,
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: C.text2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, color: C.text, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncInitialSelection();
    final names = _borrowerNames;
    final loansForUser = _loansForBorrower;
    final loan = _selectedLoan;

    final remPrincipal = _remainingPrincipal(loan);
    final estInterest = _expectedInterest(loan);
    final autoStatusText = _autoStatus(loan);

    return Scaffold(
      appBar: AppBar(title: const Text('जमा वापसी')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- 1. HIGHLIGHTED SECTION ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'उधार विवरण (हाइलाइटेड)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                ),
                const SizedBox(height: 10),

                // नाम Dropdown
                _highlightedCard(
                  child: DropdownButtonFormField<String>(
                    value: selectedBorrower,
                    decoration: const InputDecoration(
                      labelText: 'नाम चुनें',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (final n in names) DropdownMenuItem(value: n, child: Text(n)),
                    ],
                    onChanged: (v) => setState(() {
                      selectedBorrower = v;
                      selectedLoanId = null;
                      _syncInitialSelection();
                    }),
                  ),
                ),

                // दिनांक Dropdown (उधार की तारीख)
                _highlightedCard(
                  child: DropdownButtonFormField<String>(
                    value: loan?.id,
                    decoration: const InputDecoration(
                      labelText: 'उधार दिनांक चुनें',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (final l in loansForUser)
                        DropdownMenuItem(
                          value: l.id,
                          child: Text('${_fmtDate(l.date)}  •  ${rs(l.principal)}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => selectedLoanId = v),
                  ),
                ),

                // मूलधन, ब्याज दर, अवधि, संभावित ब्याज
                _highlightedCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _infoTile('मूलधन', loan == null ? '₹0' : rs(remPrincipal))),
                          Expanded(child: _infoTile('ब्याज दर', loan == null ? '0%' : '${loan.rate}% / माह')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _infoTile('अवधि', loan == null ? '-' : _formatPeriod(loan))),
                          Expanded(child: _infoTile('संभावित ब्याज', loan == null ? '₹0' : rs(estInterest))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---- 2. MANUAL SECTION (अंतिम ब्याज, ब्याज जमा, मूलधन जमा, दिनांक टाइपिंग/कैलेंडर) ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'जमा प्रविष्टि (मैनुअल)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.text),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: dateTextCtrl,
                        decoration: InputDecoration(
                          labelText: 'दिनांक (DD/MM/YYYY)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, color: C.primary),
                            onPressed: _pickCalendarDate,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                tf(finalInterestCtrl, 'अंतिम ब्याज (₹)', number: true),
                tf(interestPaidCtrl, 'ब्याज जमा (₹)', number: true),
                tf(principalPaidCtrl, 'मूलधन जमा (₹)', number: true),
              ],
            ),
          ),

          // ---- 3. AUTO SECTION (कुल जमा राशि & स्थिति) ----
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'स्वतः गणना (ऑटो)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _infoTile('कुल जमा राशि', rs(_totalDeposit))),
                    Expanded(child: _infoTile('स्थिति', autoStatusText)),
                  ],
                ),
                const SizedBox(height: 14),
                btn(
                  _editingLoanId != null ? 'सुधार सेव करें' : 'जमा सेव करें',
                  _save,
                  icon: Icons.save,
                ),
              ],
            ),
          ),

          if (_lastMsg.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _sendWhatsapp(_lastMsg, _lastPhone),
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp मैसेज भेजें'),
            ),
          ],
        ],
      ),
    );
  }
}
