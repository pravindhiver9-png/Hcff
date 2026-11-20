import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/finance_engine.dart';
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
  DateTime date = DateTime.now();

  // हर सदस्य के लिए वितरण राशि कंट्रोलर
  final Map<String, TextEditingController> _shareCtrls = {};
  // जिन सदस्यों के सक्रिय उधार का पैनल खुला है
  final Set<String> _expandedMembers = {};
  // हर सक्रिय उधार (loan.id) के लिए मैनुअल इनपुट कंट्रोलर्स
  final Map<String, TextEditingController> _finalIntCtrls = {};
  final Map<String, TextEditingController> _intPaidCtrls = {};
  final Map<String, TextEditingController> _priPaidCtrls = {};
  // जिन लोन को चेक/चुक्ता किया जा रहा है
  final Set<String> _selectedLoanIds = {};

  TextEditingController _shareCtrl(String memberId) =>
      _shareCtrls.putIfAbsent(memberId, () => TextEditingController());

  TextEditingController _fIntCtrl(String loanId, Loan l) =>
      _finalIntCtrls.putIfAbsent(loanId, () => TextEditingController());

  TextEditingController _iPaidCtrl(String loanId) =>
      _intPaidCtrls.putIfAbsent(loanId, () => TextEditingController());

  TextEditingController _pPaidCtrl(String loanId) =>
      _priPaidCtrls.putIfAbsent(loanId, () => TextEditingController());

  @override
  void dispose() {
    total.dispose();
    for (final c in _shareCtrls.values) {
      c.dispose();
    }
    for (final c in _finalIntCtrls.values) {
      c.dispose();
    }
    for (final c in _intPaidCtrls.values) {
      c.dispose();
    }
    for (final c in _priPaidCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Loan> _activeLoansForMember(String memberId) =>
      s.loans.where((l) => l.active && l.memberId == memberId).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  String _periodText(Loan l) {
    final days = date.difference(l.date).inDays;
    final safeDays = days < 0 ? 0 : days;
    final months = (safeDays / 30).floor();
    final remDays = safeDays % 30;
    if (months <= 0) return '$safeDays दिन';
    if (remDays == 0) return '$months माह ($safeDays दिन)';
    return '$months माह $remDays दिन';
  }

  double _loanTotalPaid(String loanId) {
    final iPaid = num0(_iPaidCtrl(loanId).text);
    final pPaid = num0(_pPaidCtrl(loanId).text);
    return iPaid + pPaid;
  }

  /// किसी सदस्य के चयनित उधारों में कुल कितनी जमा राशि लग रही है
  double _memberLoansSettledAmount(String memberId) {
    double sum = 0;
    for (final l in _activeLoansForMember(memberId)) {
      if (_selectedLoanIds.contains(l.id)) {
        sum += _loanTotalPaid(l.id);
      }
    }
    return sum;
  }

  /// वितरण राशि डालते ही सभी सदस्यों में बराबर राशि बाँटना
  void _distributeEquallyFromTotal(String rawTotal) {
    final t = num0(rawTotal);
    if (s.members.isEmpty) return;
    if (t <= 0) {
      for (final m in s.members) {
        _shareCtrl(m.id).clear();
      }
      setState(() {});
      return;
    }

    final each = (t / s.members.length).floorToDouble();
    final remainder = t - (each * s.members.length);

    for (var i = 0; i < s.members.length; i++) {
      final m = s.members[i];
      // यदि सदस्य के उधार चुक्ता होने के बाद बची हुई राशि है तो उस हिसाब से समायोजित करें
      final extra = (i == 0 && remainder > 0) ? remainder : 0.0;
      final val = each + extra;
      _shareCtrl(m.id).text = val == val.roundToDouble() ? val.toStringAsFixed(0) : val.toStringAsFixed(2);
    }
    setState(() {});
  }

  /// उधार चुक्ता होते ही सदस्य के वितरण राशि बॉक्स में बची हुई राशि ऑटो अपडेट करना
  void _recalculateRemainingShareForMember(String memberId, double baseShare) {
    final settled = _memberLoansSettledAmount(memberId);
    final remaining = (baseShare - settled) < 0 ? 0.0 : (baseShare - settled);
    final ctrl = _shareCtrl(memberId);
    final formatted = remaining == remaining.roundToDouble()
        ? remaining.toStringAsFixed(0)
        : remaining.toStringAsFixed(2);
    if (ctrl.text != formatted) {
      ctrl.text = formatted;
    }
  }

  Future<void> _save() async {
    final shares = <Member, double>{
      for (final m in s.members) m: num0(_shareCtrl(m.id).text)
    }..removeWhere((_, v) => v <= 0);

    // यदि किसी सदस्य ने सिर्फ़ उधार चुक्ता की राशि भरी है और वितरण बॉक्स 0/खाली है
    for (final m in s.members) {
      final settled = _memberLoansSettledAmount(m.id);
      if (settled > 0 && !shares.containsKey(m)) {
        shares[m] = settled;
      }
    }

    if (shares.isEmpty) {
      return toast(context, 'किसी सदस्य की वितरण या उधार राशि लिखें');
    }

    final sum = shares.values.fold(0.0, (a, e) => a + e);
    if (sum > s.fe.totalFund) {
      return toast(
        context,
        'कुल वितरण ${rs(sum)} फंड ${rs(s.fe.totalFund)} से ज़्यादा है',
      );
    }

    if (!await confirm(
      context,
      'कुल ${rs(sum)} बाँटें? चयनित सक्रिय उधार भी दर्ज होंगे।',
    )) {
      return;
    }

    shares.forEach((m, share) {
      double memberSettledTotal = 0;

      // 1. यदि सदस्य के उधार चुने गए हैं और राशि डाली गई है तो उन्हें चुक्ता करें
      for (final l in _activeLoansForMember(m.id)) {
        if (_selectedLoanIds.contains(l.id)) {
          final iPaid = num0(_iPaidCtrl(l.id).text);
          final pPaid = num0(_pPaidCtrl(l.id).text);
          if (iPaid > 0 || pPaid > 0) {
            final isFull = pPaid >= l.principal - 0.5;
            s.repay(
              l,
              iPaid,
              pPaid,
              date,
              isFull ? 1 : 2,
              extra: '(वितरण से चुक्ता)',
            );
            memberSettledTotal += (iPaid + pPaid);
          }
        }
      }

      // 2. यदि कोई अतिरिक्त राशि बची है और प्लान से समायोजन होना है
      final remainingForPlan = (share - memberSettledTotal) < 0 ? 0.0 : (share - memberSettledTotal);
      if (remainingForPlan > 0) {
        final plans = s.fe.planSettlement(m.id, remainingForPlan, date);
        for (final p in plans) {
          if (!_selectedLoanIds.contains(p.loan.id)) {
            s.repay(
              p.loan,
              p.interest,
              p.principal,
              date,
              p.principal >= p.loan.principal - 0.5 ? 1 : 2,
              extra: '(वितरण से समायोजित)',
            );
            memberSettledTotal += (p.interest + p.principal);
          }
        }
      }

      s.vitran.add(
        Vitran(
          id: s.newId(),
          memberId: m.id,
          share: share,
          loanSettled: memberSettledTotal,
          date: date,
        ),
      );
    });

    await s.save();
    if (!mounted) return;

    setState(() {
      total.clear();
      for (final c in _shareCtrls.values) {
        c.clear();
      }
      for (final c in _finalIntCtrls.values) {
        c.clear();
      }
      for (final c in _intPaidCtrls.values) {
        c.clear();
      }
      for (final c in _priPaidCtrls.values) {
        c.clear();
      }
      _selectedLoanIds.clear();
      _expandedMembers.clear();
    });

    toast(context, 'वितरण दर्ज हो गया');
  }

  Widget _highlightedInfoBox(Loan l) {
    final estInt = FinanceEngine.accrued(l, date);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.primary, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('दिनांक: ${dt(l.date)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text))),
              Expanded(child: Text('मूलधन: ${rs(l.principal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('अवधि: ${_periodText(l)}', style: const TextStyle(color: C.text2, fontWeight: FontWeight.w600))),
              Expanded(child: Text('संभावित ब्याज: ${rs(estInt)}', style: const TextStyle(color: C.primary, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reg = [...s.vitran]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('पैसा वितरण')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (s.isAdmin)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'कुल फंड: ${rs(s.fe.totalFund)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                  ),
                  const SizedBox(height: 10),
                  DateField(
                    label: 'वितरण / जमा दिनांक',
                    value: date,
                    onChanged: (d) => setState(() => date = d),
                  ),
                  tf(
                    total,
                    'वितरण राशि (₹) — डालते ही सभी सदस्यों में बराबर बंटेगा',
                    number: true,
                    onChanged: _distributeEquallyFromTotal,
                  ),
                  const SizedBox(height: 6),
                  sectionTitle('सभी सदस्य'),
                  for (final m in s.members) ...[
                    Builder(
                      builder: (context) {
                        final activeLoans = _activeLoansForMember(m.id);
                        final hasActiveLoan = activeLoans.isNotEmpty;
                        final isChecked = _expandedMembers.contains(m.id);
                        final shareCtrl = _shareCtrl(m.id);
                        final currentShareVal = num0(shareCtrl.text);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: C.text,
                                      ),
                                    ),
                                  ),
                                  if (hasActiveLoan) ...[
                                    const Text(
                                      'सक्रिय उधार',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: C.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Checkbox(
                                      value: isChecked,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _expandedMembers.add(m.id);
                                          } else {
                                            _expandedMembers.remove(m.id);
                                            for (final l in activeLoans) {
                                              _selectedLoanIds.remove(l.id);
                                            }
                                            _recalculateRemainingShareForMember(
                                              m.id,
                                              currentShareVal + _memberLoansSettledAmount(m.id),
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                              tf(
                                shareCtrl,
                                '${m.name} — वितरण राशि (₹)',
                                number: true,
                                onChanged: (_) => setState(() {}),
                              ),

                              // चेकबॉक्स टिक करते ही सदस्य के सभी सक्रिय उधार दिखाना
                              if (hasActiveLoan && isChecked) ...[
                                for (final l in activeLoans) ...[
                                  Builder(
                                    builder: (context) {
                                      final loanChecked = _selectedLoanIds.contains(l.id);
                                      final totalPaidForLoan = _loanTotalPaid(l.id);

                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: C.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: loanChecked ? C.primary : C.border,
                                            width: loanChecked ? 1.6 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: loanChecked,
                                                  onChanged: (checked) {
                                                    setState(() {
                                                      final prevTotalBeforeChange =
                                                          currentShareVal + _memberLoansSettledAmount(m.id);
                                                      if (checked == true) {
                                                        _selectedLoanIds.add(l.id);
                                                      } else {
                                                        _selectedLoanIds.remove(l.id);
                                                      }
                                                      _recalculateRemainingShareForMember(
                                                        m.id,
                                                        prevTotalBeforeChange,
                                                      );
                                                    });
                                                  },
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'उधार (${dt(l.date)}) — मूलधन ${rs(l.principal)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: C.text,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            _highlightedInfoBox(l),
                                            tf(
                                              _fIntCtrl(l.id, l),
                                              'अंतिम ब्याज (₹)',
                                              number: true,
                                              onChanged: (_) => setState(() {}),
                                            ),
                                            tf(
                                              _iPaidCtrl(l.id),
                                              'ब्याज जमा (₹)',
                                              number: true,
                                              onChanged: (_) {
                                                setState(() {
                                                  if (!_selectedLoanIds.contains(l.id)) {
                                                    _selectedLoanIds.add(l.id);
                                                  }
                                                  final totalPool =
                                                      num0(shareCtrl.text) + _memberLoansSettledAmount(m.id);
                                                  _recalculateRemainingShareForMember(m.id, totalPool);
                                                });
                                              },
                                            ),
                                            tf(
                                              _pPaidCtrl(l.id),
                                              'मूलधन जमा (₹)',
                                              number: true,
                                              onChanged: (_) {
                                                setState(() {
                                                  if (!_selectedLoanIds.contains(l.id)) {
                                                    _selectedLoanIds.add(l.id);
                                                  }
                                                  final totalPool =
                                                      num0(shareCtrl.text) + _memberLoansSettledAmount(m.id);
                                                  _recalculateRemainingShareForMember(m.id, totalPool);
                                                });
                                              },
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: C.bg,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text(
                                                    'कुल जमा राशि (ऑटो):',
                                                    style: TextStyle(fontWeight: FontWeight.bold, color: C.text),
                                                  ),
                                                  Text(
                                                    rs(totalPaidForLoan),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: C.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  btn('सेव करें', _save, icon: Icons.save),
                ],
              ),
            ),
          sectionTitle('वितरण रजिस्टर'),
          if (reg.isEmpty)
            const AppCard(
              child: Text('अभी कोई वितरण नहीं', style: TextStyle(color: C.text2)),
            ),
          for (final v in reg)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.memberById(v.memberId)?.name ?? ''} • ${dt(v.date)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: C.text),
                  ),
                  Text(
                    'हिस्सा ${rs(v.share)} • उधार समायोजन ${rs(v.loanSettled)} • नेट ${rs(v.net)}',
                    style: const TextStyle(color: C.text2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
