import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
import '../core/utils.dart';

const kIdKey = {
  'Members': 'Member_ID',
  'Udhar_Khata': 'Loan_ID',
  'Kharch': 'ID',
  'Atirikt_Rashi': 'ID',
  'Paisa_Vitran': 'ID',
  'Jama_Log': 'ID',
};
const kDataSheets = ['Members', 'Monthly_Jama', 'Udhar_Khata', 'Kharch', 'Atirikt_Rashi', 'Paisa_Vitran', 'Jama_Log'];

class Stats {
  const Stats({
    required this.months, required this.members, required this.jama, required this.lent,
    required this.interest, required this.expense, required this.extra,
    required this.vitran, required this.balance,
  });
  final int months, members;
  final num jama, lent, interest, expense, extra, vitran, balance;
}

class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool dark = false, unlocked = false, loading = false;
  String lang = 'hi';
  String scriptUrl = '', memberId = '', pin = '', mpinHash = '';
  Map<String, dynamic> me = {};
  Map<String, List<Map<String, dynamic>>> d = {};
  Map<String, dynamic> settings = {};

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    dark = _p.getBool('dark') ?? false;
    lang = _p.getString('lang') ?? 'hi';
    scriptUrl = _p.getString('url') ?? '';
    memberId = _p.getString('mid') ?? '';
    pin = _p.getString('pin') ?? '';
    mpinHash = _p.getString('mpin') ?? '';
    final cached = _p.getString('cache');
    if (cached != null) {
      try { _ingest(jsonDecode(cached) as Map<String, dynamic>); } catch (_) {}
    }
  }

  // ---------- helpers ----------
  String t(String hi, String en) => lang == 'en' ? en : hi;
  bool get hasLogin => memberId.isNotEmpty;
  String get role => '${me['Role'] ?? 'Member'}';
  bool get canWrite => role == 'Admin' || role == 'Co-Admin';
  bool get isAdmin => role == 'Admin';
  String get myName => '${me['Full_Name'] ?? ''}';
  List<Map<String, dynamic>> rows(String k) => d[k] ?? [];

  List<Map<String, dynamic>> get members => rows('Members');
  List<Map<String, dynamic>> get activeMembers =>
      members.where((m) => '${m['Status']}' != 'निष्क्रिय').toList();
  List<Loan> get loans => rows('Udhar_Khata').map(Loan.new).toList();
  List<Loan> get activeLoans => loans.where((l) => l.active).toList();

  Map<String, dynamic>? memberByName(String n) {
    final k = n.trim().toLowerCase();
    if (k.isEmpty) return null;
    for (final m in members) {
      if ('${m['Full_Name']}'.trim().toLowerCase() == k) return m;
    }
    return null;
  }

  List<String> get nameSuggestions {
    final s = <String>{};
    for (final m in members) { s.add('${m['Full_Name']}'.trim()); }
    for (final l in loans) { s.add(l.name); }
    s.remove('');
    return s.toList()..sort();
  }

  num get monthly => toNum(settings['Monthly_Jama'] ?? 200);
  num get memberRate => toNum(settings['Member_Rate'] ?? 2);
  num get nonMemberRate => toNum(settings['NonMember_Rate'] ?? 5);
  DateTime get groupStart => pd('${settings['Group_Start'] ?? '2025-02'}-01') ?? DateTime(2025, 2, 1);

  num jamaAt(String mid, int y, int m) {
    for (final r in rows('Monthly_Jama')) {
      if ('${r['Member_ID']}' == mid && toNum(r['Year']) == y) return toNum(r['M$m']);
    }
    return 0;
  }

  num advanceOf(String mid) {
    for (final m in members) {
      if ('${m['Member_ID']}' == mid) return toNum(m['Advance_Balance']);
    }
    return 0;
  }

  num _sum(String sheet, String key) => rows(sheet).fold<num>(0, (a, r) => a + toNum(r[key]));

  Stats get stats {
    num jama = 0;
    for (final r in rows('Monthly_Jama')) {
      for (var m = 1; m <= 12; m++) { jama += toNum(r['M$m']); }
    }
    for (final m in members) { jama += toNum(m['Advance_Balance']); }
    final lent = activeLoans.fold<num>(0, (a, l) => a + l.principal);
    final interest = loans.fold<num>(0, (a, l) => a + l.intPaid);
    final exp = _sum('Kharch', 'Amount');
    final extra = _sum('Atirikt_Rashi', 'Amount');
    final vit = _sum('Paisa_Vitran', 'Per_Member');
    final gs = groupStart, n = DateTime.now();
    final months = ((n.year - gs.year) * 12 + n.month - gs.month).clamp(0, 9999);
    return Stats(
      months: months, members: activeMembers.length, jama: jama, lent: lent,
      interest: interest, expense: exp, extra: extra, vitran: vit,
      balance: jama + interest + extra - exp - vit - lent,
    );
  }

  /// Dashboard table: member vs non-member borrowers (active loans).
  (List<List<String>>, List<String>) categoryTable() {
    final now = DateTime.now();
    final act = activeLoans;
    List<String> row(String label, String rate, List<Loan> ls) => [
          label, rate, '${ls.map((l) => l.name).toSet().length}',
          rs(ls.fold<num>(0, (a, l) => a + l.principal)),
          rs(ls.fold<num>(0, (a, l) => a + l.potential(now) + l.carry).round()),
        ];
    final mem = act.where((l) => memberByName(l.name) != null).toList();
    final non = act.where((l) => memberByName(l.name) == null).toList();
    return (
      [
        row('समूह सदस्य', '${ns(memberRate)}% प्रति माह', mem),
        row('गैर-सदस्य / बाहरी', '${ns(nonMemberRate)}% प्रति माह', non),
      ],
      row('कुल योग', '', act)..[1] = '',
    );
  }

  // ---------- prefs ----------
  Future<void> setDark(bool v) async { dark = v; await _p.setBool('dark', v); notifyListeners(); }
  Future<void> setLang(String v) async { lang = v; await _p.setString('lang', v); notifyListeners(); }
  Future<void> saveUrl(String u) async { scriptUrl = u; await _p.setString('url', u); }

  String _hash(String s) => sha256.convert(utf8.encode('hcff2::$s')).toString();
  bool checkMpin(String v) => _hash(v) == mpinHash;
  Future<void> setMpin(String v) async {
    mpinHash = _hash(v);
    await _p.setString('mpin', mpinHash);
    unlocked = true;
    notifyListeners();
    try { await call('mpinSet'); } catch (_) {}
  }

  void unlock() { unlocked = true; notifyListeners(); }

  Future<void> logout() async {
    memberId = ''; pin = ''; mpinHash = ''; me = {}; d = {}; unlocked = false;
    await _p.remove('mid'); await _p.remove('pin'); await _p.remove('mpin'); await _p.remove('cache');
    notifyListeners();
  }

  // ---------- network ----------
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> extra = const {}, bool auth = true]) async {
    if (scriptUrl.isEmpty) throw Exception('Apps Script URL सेट नहीं है');
    final client = http.Client();
    try {
      final body = jsonEncode({
        'action': action,
        if (auth) 'memberId': memberId,
        if (auth) 'pin': pin,
        ...extra,
      });
      final req = http.Request('POST', Uri.parse(scriptUrl))
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = body;
      var res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 40)));
      var guard = 0;
      while ({301, 302, 303, 307, 308}.contains(res.statusCode) && guard++ < 3) {
        res = await client.get(Uri.parse(res.headers['location']!));
      }
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['ok'] != true) throw Exception(j['error'] ?? 'अज्ञात त्रुटि');
      return j;
    } finally {
      client.close();
    }
  }

  /// Returns null on success, or the list of accounts if the person must choose.
  Future<List<Map<String, dynamic>>?> login(String id, String pinIn) async {
    final r = await call('login', {'id': id, 'pin': pinIn}, false);
    if (r['accounts'] != null) {
      return (r['accounts'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final m = Map<String, dynamic>.from(r['member']);
    memberId = '${m['Member_ID']}'; pin = pinIn; me = m; unlocked = false;
    await _p.setString('mid', memberId);
    await _p.setString('pin', pin);
    notifyListeners();
    try { await refresh(); } catch (_) {}
    return null;
  }

  void _ingest(Map<String, dynamic> r) {
    final data = Map<String, dynamic>.from(r['data'] ?? {});
    d = {
      for (final k in kDataSheets)
        k: ((data[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList()
    };
    settings = Map<String, dynamic>.from(r['settings'] ?? {});
    if (r['me'] != null) me = Map<String, dynamic>.from(r['me']);
  }

  Future<void> refresh() async {
    loading = true; notifyListeners();
    try {
      final r = await call('getAll');
      _ingest(r);
      await _p.setString('cache', jsonEncode(r));
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// ops: [{op:'add'|'update'|'delete'|'saveJama', ...}] applied atomically on the server.
  Future<void> batch(List<Map<String, dynamic>> ops) async {
    await call('batch', {'ops': ops});
    await refresh();
  }

  Future<void> saveSettings(Map<String, dynamic> s) async {
    await call('saveSettings', {'settings': s});
    await refresh();
  }
}
