import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import 'finance_engine.dart';
import 'sheet_sync_service.dart';

class Store extends ChangeNotifier {
  static final Store I = Store._();
  Store._();

  late SharedPreferences prefs;
  List<Member> members = [];
  List<Loan> loans = [];
  List<MasikJama> jama = [];
  List<MoneyEntry> kharch = [], atirikt = [];
  List<Vitran> vitran = [];
  double monthlyAmount = 200, memberRate = 2, outsiderRate = 5;
  String sheetUrl = '';
  bool pending = false;
  DateTime? lastSync;
  Member? user;
  String? mpin, mpinUid;
  bool _syncing = false;
  int _n = 0;

  FinanceEngine get fe => FinanceEngine(this);
  bool get canEdit => user?.canEdit ?? false;
  bool get isAdmin => user?.isAdmin ?? false;
  String newId() => '${DateTime.now().microsecondsSinceEpoch}${_n++}';
  Member? memberById(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('data');
    if (raw != null) {
      fromJson(jsonDecode(raw));
    } else {
      // शुरुआती एडमिन (स्पेक के अनुसार)। लॉगिन के बाद Members स्क्रीन से पासवर्ड बदल सकते हैं।
      members = [Member(id: 'm1', name: 'प्रवीण धीवर', mobile: '9977654981', loginId: 'Pravin001', password: 'Tukku2124', role: 'admin')];
    }
    sheetUrl = prefs.getString('sheetUrl') ?? '';
    pending = prefs.getBool('pending') ?? false;
    mpin = prefs.getString('mpin');
    mpinUid = prefs.getString('mpinUid');
    if (pending) sync();
  }

  Map<String, dynamic> toJson() => {
        'members': members.map((e) => e.toJson()).toList(),
        'loans': loans.map((e) => e.toJson()).toList(),
        'jama': jama.map((e) => e.toJson()).toList(),
        'kharch': kharch.map((e) => e.toJson()).toList(),
        'atirikt': atirikt.map((e) => e.toJson()).toList(),
        'vitran': vitran.map((e) => e.toJson()).toList(),
        'settings': {'monthly': monthlyAmount, 'memberRate': memberRate, 'outsiderRate': outsiderRate},
      };

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      ((v as List?) ?? []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

  void fromJson(Map<String, dynamic> j) {
    members = _list(j['members'], Member.fromJson);
    loans = _list(j['loans'], Loan.fromJson);
    jama = _list(j['jama'], MasikJama.fromJson);
    kharch = _list(j['kharch'], MoneyEntry.fromJson);
    atirikt = _list(j['atirikt'], MoneyEntry.fromJson);
    vitran = _list(j['vitran'], Vitran.fromJson);
    final st = (j['settings'] as Map?) ?? {};
    monthlyAmount = (st['monthly'] as num?)?.toDouble() ?? 200;
    memberRate = (st['memberRate'] as num?)?.toDouble() ?? 2;
    outsiderRate = (st['outsiderRate'] as num?)?.toDouble() ?? 5;
  }

  Future<void> save() async {
    await prefs.setString('data', jsonEncode(toJson()));
    pending = true;
    await prefs.setBool('pending', true);
    notifyListeners();
    sync();
  }

  Future<void> sync() async {
    if (sheetUrl.isEmpty || _syncing) return;
    _syncing = true;
    final ok = await SheetSyncService.push(sheetUrl, jsonEncode(toJson()));
    if (ok) {
      pending = false;
      lastSync = DateTime.now();
      await prefs.setBool('pending', false);
    }
    _syncing = false;
    notifyListeners();
  }

  Future<String> restoreFromSheet() async {
    if (sheetUrl.isEmpty) return 'पहले Sheet URL डालें';
    final body = await SheetSyncService.pull(sheetUrl);
    if (body == null || body.trim().isEmpty || body.trim() == '{}') return 'शीट से डेटा नहीं मिला (नेट/URL जाँचें)';
    try {
      fromJson(jsonDecode(body));
      final keep = memberById(user?.id);
      user = keep ?? (members.isNotEmpty ? members.first : null);
      await save();
      return 'रीस्टोर पूरा ✓';
    } catch (e) {
      return 'रीस्टोर में त्रुटि: $e';
    }
  }

  Future<void> setSheetUrl(String u) async {
    sheetUrl = u.trim();
    await prefs.setString('sheetUrl', sheetUrl);
  }

  Future<void> setMpin(String pin, String uid) async {
    mpin = pin;
    mpinUid = uid;
    await prefs.setString('mpin', pin);
    await prefs.setString('mpinUid', uid);
  }

  Future<void> clearMpin() async {
    mpin = null;
    mpinUid = null;
    await prefs.remove('mpin');
    await prefs.remove('mpinUid');
  }

  Member? findLogin(String idOrMobile, String pw) {
    final x = idOrMobile.trim().toLowerCase();
    for (final m in members) {
      if ((m.loginId.toLowerCase() == x || m.mobile == x) && m.password == pw) return m;
    }
    return null;
  }

  /// जमा वापसी। cond: 1 = पूर्ण जमा, 2 = बचत मूलधन रोलओवर, 3 = 16वें दिन '+' रोलओवर
  /// (save() कॉल करने वाले को करना है)
  void repay(Loan l, double interest, double principal, DateTime date, int cond, {String extra = ''}) {
    l.interestPaid += interest;
    l.principalPaid += principal;
    l.repayDate = date;
    l.status = 'पूर्ण जमा';
    final rest = l.principal - l.principalPaid;
    if (cond == 1 || rest < 0.5) {
      l.note = ('पूर्ण जमा $extra').trim();
    } else {
      final tag = cond == 3 ? '16वां दिन +' : 'बचत मूलधन';
      l.note = '$tag → ₹${rest.toStringAsFixed(0)} नई एंट्री में $extra'.trim();
      loans.add(Loan(id: newId(), memberId: l.memberId, borrower: l.borrower, principal: rest, date: date, rate: l.rate, note: tag, parentId: l.id));
    }
  }
}
