import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/utils.dart';
import '../state/app_state.dart';
import 'pdf_service.dart';

/// All report definitions. Mobile numbers appear ONLY in the statement.
class Reports {
  static String _today() => fd(DateTime.now());

  static List<Widget> dashboard(AppState s) {
    final st = s.stats;
    final (cat, total) = s.categoryTable();
    return Rpt.report(
      title: 'समूह विवरण',
      sub: _today(),
      top: [
        Rpt.miniCards([
          ('समूह का कुल महीना', '${st.months} माह'),
          ('कुल सदस्य', '${st.members}'),
          ('कुल जमा राशि', rs(st.jama)),
          ('दिया गया कुल उधार', rs(st.lent)),
          ('कुल ब्याज जमा', rs(st.interest)),
          ('समूह में शेष राशि', rs(st.balance)),
          ('कुल खर्च', rs(st.expense)),
          ('कुल अतिरिक्त राशि', rs(st.extra)),
          ('कुल पैसा वितरण', rs(st.vitran)),
        ]),
        const SizedBox(height: 10),
        Rpt.note('ऋण धारक एवं श्रेणीवार विवरण', b: true),
      ],
      hd: ['ऋण श्रेणी', 'ब्याज दर', 'उधारकर्ता संख्या', 'कुल उधार राशि', 'संभावित कुल ब्याज'],
      rows: cat,
      totals: total,
      flex: [3, 3, 2, 3, 3],
    );
  }

  static List<Widget> jamaYearly(AppState s, int year) {
    final ms = s.activeMembers;
    num grand = 0;
    final rows = <List<String>>[];
    for (var i = 0; i < ms.length; i++) {
      final id = '${ms[i]['Member_ID']}';
      num tot = 0;
      final r = <String>['${i + 1}', '${ms[i]['Full_Name']}'];
      for (var m = 1; m <= 12; m++) {
        final v = s.jamaAt(id, year, m);
        tot += v;
        r.add(v > 0 ? ns(v) : '-');
      }
      r.add(ns(tot));
      grand += tot;
      rows.add(r);
    }
    return Rpt.report(
      title: 'वार्षिक मासिक जमा सूची - $year',
      sub: _today(),
      hd: ['क्र.', 'सदस्य का नाम', ...hiMonthsShort, 'कुल'],
      flex: [1, 5, ...List.filled(12, 2), 3],
      rows: rows,
      totals: ['', 'कुल योग', ...List.generate(12, (m) => ns(ms.fold<num>(0, (a, x) => a + s.jamaAt('${x['Member_ID']}', year, m + 1)))), ns(grand)],
      first: 22,
      rest: 30,
      bottom: [
        Rpt.note('कुल सदस्य: ${ms.length}'),
        Rpt.note('मासिक कुल संग्रह: ${rs(ms.length * s.monthly)}'),
        Rpt.note('वर्ष कुल जमा राशि: ${rs(grand)}', b: true),
        Rpt.note('शब्दों में: ${amountInWords(grand)}'),
        Rpt.signature(),
      ],
    );
  }

  static List<Widget> jamaMonthly(AppState s, int year, int month) {
    final ms = s.activeMembers;
    num tot = 0;
    var paid = 0;
    final rows = <List<String>>[];
    for (var i = 0; i < ms.length; i++) {
      final v = s.jamaAt('${ms[i]['Member_ID']}', year, month);
      tot += v;
      if (v > 0) paid++;
      rows.add(['${i + 1}', '${ms[i]['Full_Name']}', v > 0 ? ns(v) : '-', v > 0 ? 'जमा' : 'बाकी']);
    }
    final pct = ms.isEmpty ? 0 : (paid * 100 / ms.length).round();
    return Rpt.report(
      title: 'मासिक जमा सूची - ${hiMonths[month - 1]} $year',
      sub: _today(),
      hd: ['क्र.', 'सदस्य का नाम', 'जमा राशि (₹)', 'स्थिति'],
      flex: [1, 5, 3, 2],
      rows: rows,
      first: 22,
      rest: 30,
      bottom: [
        Rpt.note('कुल सदस्य: ${ms.length}'),
        Rpt.note('कुल जमा राशि: ${rs(tot)}', b: true),
        Rpt.note('जमा स्थिति: $pct%'),
        Rpt.signature(),
      ],
    );
  }

  static List<Widget> udharList(List<Loan> ls, String filter) {
    final rows = <List<String>>[];
    for (var i = 0; i < ls.length; i++) {
      final l = ls[i];
      rows.add(['${i + 1}', l.name, fd(l.date), ns(l.principal), '${ns(l.rate)}%', ns(l.intPaid), ns(l.prinPaid), l.status]);
    }
    return Rpt.report(
      title: 'उधार सूची ($filter)',
      sub: _today(),
      hd: ['क्र.', 'नाम', 'दिनांक', 'मूलधन', 'दर', 'ब्याज जमा', 'मूलधन जमा', 'स्थिति'],
      flex: [1, 4, 3, 3, 2, 3, 3, 3],
      rows: rows,
      totals: ['', 'कुल', '', ns(ls.fold<num>(0, (a, l) => a + l.principal)), '', ns(ls.fold<num>(0, (a, l) => a + l.intPaid)), ns(ls.fold<num>(0, (a, l) => a + l.prinPaid)), ''],
      first: 22,
      rest: 30,
    );
  }

  /// Statement: the only PDF that shows the mobile number + dark-green background.
  static List<Widget> statement(AppState s, String name, String filter) {
    final ls = s.loans.where((l) => l.name.toLowerCase() == name.trim().toLowerCase() && (filter == 'सभी' || l.status == filter)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final mobile = ls.map((l) => l.mobile).firstWhere((m) => m.isNotEmpty, orElse: () => '-');
    final lent = ls.fold<num>(0, (a, l) => a + l.principal);
    final pp = ls.fold<num>(0, (a, l) => a + l.prinPaid);
    final ip = ls.fold<num>(0, (a, l) => a + l.intPaid);
    final out = ls.where((l) => l.active).fold<num>(0, (a, l) => a + l.principal);
    final rows = <List<String>>[
      for (var i = 0; i < ls.length; i++)
        [
          '${i + 1}', fd(ls[i].date), ns(ls[i].principal), '${ns(ls[i].rate)}%', ns(ls[i].intPaid),
          ns(ls[i].prinPaid), fd(ls[i].returnDate), ls[i].status,
        ]
    ];
    return Rpt.report(
      title: 'ऋण स्टेटमेंट',
      sub: _today(),
      stmt: true,
      first: 9,
      rest: 19,
      top: [
        Rpt.note('नाम: $name', b: true),
        Rpt.note('मोबाइल नं.: $mobile     |     स्थिति: $filter'),
        const SizedBox(height: 4),
        Rpt.miniCards([
          ('कुल उधार', rs(lent)),
          ('मूलधन जमा', rs(pp)),
          ('ब्याज जमा', rs(ip)),
          ('बकाया मूलधन', rs(out)),
        ], perRow: 4),
        const SizedBox(height: 6),
        Rpt.note('ऋण इतिहास एवं लेन-देन विवरण', b: true),
      ],
      hd: ['क्र.', 'दिनांक', 'मूलधन', 'दर', 'ब्याज जमा', 'मूलधन जमा', 'जमा दिनांक', 'स्थिति'],
      flex: [1, 3, 3, 2, 3, 3, 3, 3],
      rows: rows,
    );
  }

  static List<Widget> kharchAtirikt(AppState s) {
    List<List<String>> mk(String sheet, String key) {
      final r = s.rows(sheet);
      return [for (var i = 0; i < r.length; i++) ['${i + 1}', fds(r[i]['Date']), '${r[i][key] ?? ''}', ns(toNum(r[i]['Amount']))]];
    }
    final k = s.rows('Kharch'), a = s.rows('Atirikt_Rashi');
    return [
      ...Rpt.report(
        title: 'खर्च की सूची', sub: _today(), hd: ['क्र.', 'दिनांक', 'विवरण', 'राशि'], flex: [1, 3, 6, 3],
        rows: mk('Kharch', 'Details'), totals: ['', '', 'कुल खर्च', ns(k.fold<num>(0, (x, r) => x + toNum(r['Amount'])))], first: 22, rest: 30,
      ),
      ...Rpt.report(
        title: 'अतिरिक्त राशि की सूची', sub: _today(), hd: ['क्र.', 'दिनांक', 'विवरण', 'राशि'], flex: [1, 3, 6, 3],
        rows: mk('Atirikt_Rashi', 'Note'), totals: ['', '', 'कुल अतिरिक्त राशि', ns(a.fold<num>(0, (x, r) => x + toNum(r['Amount'])))], first: 22, rest: 30,
      ),
    ];
  }

  static List<Widget> vitran(AppState s) {
    final r = s.rows('Paisa_Vitran');
    return Rpt.report(
      title: 'वितरण राशि की सूची',
      sub: _today(),
      hd: ['क्र.', 'दिनांक', 'सदस्य', 'वितरण राशि', 'समायोजन', 'अंतिम राशि'],
      flex: [1, 3, 5, 3, 3, 3],
      rows: [for (var i = 0; i < r.length; i++) ['${i + 1}', fds(r[i]['Date']), '${r[i]['Member_Name']}', ns(toNum(r[i]['Per_Member'])), ns(toNum(r[i]['Adjustment'])), ns(toNum(r[i]['Final_Amount']))]],
      totals: ['', '', 'कुल', ns(r.fold<num>(0, (a, x) => a + toNum(x['Per_Member']))), ns(r.fold<num>(0, (a, x) => a + toNum(x['Adjustment']))), ns(r.fold<num>(0, (a, x) => a + toNum(x['Final_Amount'])))],
      first: 22,
      rest: 30,
    );
  }

  static List<Widget> memberJama(AppState s, Map<String, dynamic> m) {
    final id = '${m['Member_ID']}';
    final rows = <List<String>>[];
    num tot = 0;
    final gs = s.groupStart, now = DateTime.now();
    for (var y = gs.year; y <= now.year; y++) {
      for (var mo = 1; mo <= 12; mo++) {
        final v = s.jamaAt(id, y, mo);
        if (v > 0) {
          tot += v;
          rows.add(['${rows.length + 1}', '$y', hiMonths[mo - 1], ns(v), 'जमा']);
        }
      }
    }
    return Rpt.report(
      title: 'सदस्य जमा सूची - ${m['Full_Name']}',
      sub: _today(),
      hd: ['क्र.', 'वर्ष', 'माह', 'जमा राशि', 'स्थिति'],
      flex: [1, 2, 3, 3, 2],
      rows: rows,
      totals: ['', '', 'कुल जमा', ns(tot), ''],
      bottom: [Rpt.note('एडवांस शेष: ${rs(s.advanceOf(id))}')],
      first: 22,
      rest: 30,
    );
  }
}
