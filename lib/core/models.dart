import 'dart:math';
import 'utils.dart';

/// Wrapper over a row of the Udhar_Khata sheet.
class Loan {
  Loan(this.m);
  final Map<String, dynamic> m;

  @override
  bool operator ==(Object o) => o is Loan && o.id == id;
  @override
  int get hashCode => id.hashCode;

  String get id => '${m['Loan_ID']}';
  String get name => '${m['Name'] ?? ''}'.trim();
  String get mobile => '${m['Mobile'] ?? ''}';
  num get principal => toNum(m['Principal']);
  DateTime get date => pd(m['Date']) ?? DateTime.now();
  num get rate => toNum(m['Rate']);
  num get intPaid => toNum(m['Interest_Paid']);
  num get prinPaid => toNum(m['Principal_Paid']);
  num get carry => toNum(m['Carry_Interest']);
  DateTime? get returnDate => pd(m['Return_Date']);
  bool get active => '${m['Status']}' == 'सक्रिय';
  String get status => '${m['Status']}';

  int daysTo(DateTime d) => max(0, d.difference(date).inDays);

  /// Estimated interest: rate % per month, pro-rata by days (30-day month).
  num potential(DateTime d) => principal * rate / 100 * daysTo(d) / 30;

  /// "old + new" style text when old interest is carried forward.
  String potentialText(DateTime d) {
    final p = potential(d).round();
    return carry > 0 ? '₹${carry.round()} + ₹$p' : '₹$p';
  }
}

class RepayInput {
  RepayInput(this.loan, this.finalInt, this.intPaid, this.prinPaid, this.date);
  final Loan loan;
  final num finalInt, intPaid, prinPaid;
  final DateTime date;
  num get total => intPaid + prinPaid;
  bool get any => total > 0;
}

class RepayPlan {
  RepayPlan(this.update, this.newLoan, this.note);
  final Map<String, dynamic> update;
  final Map<String, dynamic>? newLoan;
  final String note;
}

/// Carry-forward rules from the blueprint (Udhar Wapsi):
/// 1) interest fully paid, principal part-paid  -> new loan = remaining principal
/// 2) interest part-paid, principal fully paid  -> new loan = unpaid interest as
///    principal, dated return date + 15 days
/// 3) both part-paid -> new loan = remaining principal, old unpaid interest is
///    kept separately in Carry_Interest and shown as "old + new".
RepayPlan planRepay(RepayInput r) {
  final l = r.loan;
  final update = <String, dynamic>{
    'Final_Interest': r.finalInt,
    'Interest_Paid': r.intPaid,
    'Principal_Paid': r.prinPaid,
    'Total_Paid': r.total,
    'Return_Date': iso(r.date),
    'Status': 'पूर्ण जमा',
  };
  final remP = l.principal - r.prinPaid;
  final remI = r.finalInt - r.intPaid;
  Map<String, dynamic>? nl;
  var note = '';
  Map<String, dynamic> base(num principal, DateTime date, num carry, String n) => {
        'Name': l.name,
        'Mobile': l.mobile,
        'Principal': principal,
        'Date': iso(date),
        'Rate': l.rate,
        'Interest_Paid': 0,
        'Principal_Paid': 0,
        'Total_Paid': 0,
        'Status': 'सक्रिय',
        'Carry_Interest': carry,
        'Note': n,
      };
  if (remP > 0) {
    nl = base(remP, r.date, remI > 0 ? remI : 0, 'शेष मूलधन (पुराना #${l.id})');
    note = 'नई सक्रिय एंट्री: शेष मूलधन ₹${ns(remP)}'
        '${remI > 0 ? ' + बकाया ब्याज ₹${ns(remI)}' : ''}';
  } else if (remI > 0) {
    final d = r.date.add(const Duration(days: 15));
    nl = base(remI, d, 0, 'बकाया ब्याज (पुराना #${l.id}) - 15 दिन की मोहलत');
    note = 'नई सक्रिय एंट्री: बकाया ब्याज ₹${ns(remI)} (दिनांक ${fd(d)})';
  }
  return RepayPlan({'Loan_ID': l.id, ...update}, nl, note);
}
