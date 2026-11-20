import '../models/app_models.dart';
import 'store.dart';

class SettlePlan {
  final Loan loan;
  final double interest, principal;
  SettlePlan(this.loan, this.interest, this.principal);
}

/// सारे फॉर्मूले एक ही जगह।
/// कुल फंड = (कुल जमा + कुल ब्याज + कुल अतिरिक्त) − (सक्रिय उधार + खर्च + पैसा वितरण)
/// (सक्रिय उधार = दिया गया उधार − लौटा हुआ मूलधन, इसलिए मूलधन वापस आते ही फंड में जुड़ जाता है)
class FinanceEngine {
  final Store s;
  FinanceEngine(this.s);

  static double _sum<T>(Iterable<T> it, double Function(T) f) =>
      it.fold(0.0, (a, e) => a + f(e));

  double get kulJama => _sum<MasikJama>(s.jama, (e) => e.amount);
  double get kulByaj => _sum<Loan>(s.loans, (e) => e.interestPaid);
  double get kulAtirikt => _sum<MoneyEntry>(s.atirikt, (e) => e.amount);
  double get kulKharch => _sum<MoneyEntry>(s.kharch, (e) => e.amount);
  double get kulVitran => _sum<Vitran>(s.vitran, (e) => e.share);
  double get sakriyUdhar =>
      _sum<Loan>(s.loans.where((l) => l.active), (e) => e.principal);
  double get totalFund =>
      kulJama + kulByaj + kulAtirikt - sakriyUdhar - kulKharch - kulVitran;

  /// साधारण ब्याज: मूलधन × दर% × (दिन ÷ 30)
  static double accrued(Loan l, DateTime asOf) {
    final days = asOf.difference(l.date).inDays;
    if (days <= 0) return 0;
    return (l.principal * l.rate / 100 * (days / 30.0)).roundToDouble();
  }

  // ---- मासिक जमा ----
  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static DateTime addMonths(DateTime d, int n) =>
      DateTime(d.year, d.month + n, 1);
  Set<String> paidMonths(String memberId) =>
      s.jama.where((e) => e.memberId == memberId).map((e) => e.month).toSet();
  double memberJama(String memberId) => _sum<MasikJama>(
      s.jama.where((e) => e.memberId == memberId), (e) => e.amount);
  int advanceMonths(String memberId) {
    final now = monthKey(DateTime.now());
    return paidMonths(memberId).where((m) => m.compareTo(now) > 0).length;
  }

  String? lastPaidMonth(String memberId) {
    final p = paidMonths(memberId).toList()..sort();
    return p.isEmpty ? null : p.last;
  }

  // ---- पैसा वितरण: सक्रिय उधार का समायोजन (पहले ब्याज, फिर मूलधन) ----
  List<SettlePlan> planSettlement(
      String memberId, double share, DateTime date) {
    final loans = s.loans
        .where((l) => l.active && l.memberId == memberId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    var left = share;
    final plans = <SettlePlan>[];
    for (final l in loans) {
      if (left <= 0) break;
      final ac = accrued(l, date);
      final i = ac < left ? ac : left;
      left -= i;
      final p = l.principal < left ? l.principal : left;
      left -= p;
      if (i + p > 0) plans.add(SettlePlan(l, i, p));
    }
    return plans;
  }

  double settlementTotal(List<SettlePlan> p) =>
      p.fold(0.0, (a, e) => a + e.interest + e.principal);
}
