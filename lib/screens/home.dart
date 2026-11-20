import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/palette.dart';
import '../core/utils.dart';
import '../pdf/pdf_service.dart';
import '../pdf/reports.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'forms.dart';
import 'lists.dart';
import 'settings.dart';

List<StatCard> summaryCards(AppState s, {bool full = true}) {
  final st = s.stats;
  return [
    StatCard(icon: Icons.account_balance, title: 'कुल फंड (शेष)', value: rs(st.balance), color: AppPalette.violet),
    StatCard(icon: Icons.savings, title: 'कुल जमा', value: rs(st.jama), color: AppPalette.blue),
    StatCard(icon: Icons.trending_up, title: 'कुल ब्याज', value: rs(st.interest)),
    StatCard(icon: Icons.handshake, title: 'सक्रिय उधार', value: rs(st.lent), color: AppPalette.amber),
    StatCard(icon: Icons.receipt_long, title: 'खर्च', value: rs(st.expense), color: AppPalette.red),
    StatCard(icon: Icons.payments, title: 'पैसा वितरण', value: rs(st.vitran)),
    StatCard(icon: Icons.add_card, title: 'अतिरिक्त राशि', value: rs(st.extra)),
    StatCard(icon: Icons.groups, title: 'कुल सदस्य', value: '${st.members}', note: '${st.months} माह से'),
  ];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    try {
      await context.read<AppState>().refresh();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  List<(DateTime, String, String, num)> _recent(AppState s) {
    final a = <(DateTime, String, String, num)>[];
    for (final l in s.loans) {
      a.add((l.date, 'उधार एंट्री', l.name, l.principal));
      if (l.returnDate != null) a.add((l.returnDate!, 'उधार वापसी', l.name, toNum(l.m['Total_Paid'])));
    }
    for (final r in s.rows('Jama_Log')) { a.add((pd(r['Date']) ?? DateTime(2000), 'मासिक जमा', '${r['Name']} (${r['Month_Label']})', toNum(r['Amount']))); }
    for (final r in s.rows('Kharch')) { a.add((pd(r['Date']) ?? DateTime(2000), 'खर्च', '${r['Details']}', toNum(r['Amount']))); }
    for (final r in s.rows('Atirikt_Rashi')) { a.add((pd(r['Date']) ?? DateTime(2000), 'अतिरिक्त राशि', '${r['Note'] ?? ''}', toNum(r['Amount']))); }
    final seen = <String>{};
    for (final r in s.rows('Paisa_Vitran')) {
      final k = '${r['Date']}|${r['Per_Member']}';
      if (seen.add(k)) a.add((pd(r['Date']) ?? DateTime(2000), 'पैसा वितरण', 'प्रति सदस्य', toNum(r['Per_Member'])));
    }
    a.sort((x, y) => y.$1.compareTo(x.$1));
    return a.take(15).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    final forms = <(String, IconData, Widget)>[
      ('उधार एंट्री', Icons.request_quote, const UdharEntryScreen()),
      ('उधार वापसी', Icons.assignment_return, const WapsiScreen()),
      ('मासिक जमा', Icons.calendar_month, const JamaEntryScreen()),
      ('खर्च', Icons.receipt_long, const KharchScreen()),
      ('अतिरिक्त राशि', Icons.add_card, const AtiriktScreen()),
      ('पैसा वितरण', Icons.payments, const VitranScreen()),
    ];
    final recent = _recent(s);
    return AppScaffold(
      title: s.t('डैशबोर्ड / होम', 'Dashboard / Home'),
      drawer: const AppDrawer(),
      actions: [
        IconButton(
          onPressed: s.loading ? null : _sync,
          icon: s.loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_done_outlined),
        ),
        IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      ],
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
          RaisedCard(
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: p.mint, shape: BoxShape.circle, border: Border.all(color: p.border)),
                child: Icon(Icons.groups, color: p.primary, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('हमारी चिट फंड फैमिली 2.0', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.deep)),
                  Text('साथ मिलकर, आगे बढ़ें...', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Flexible(child: Text(s.myName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    RoleBadge(s.role),
                  ]),
                ]),
              ),
            ]),
          ),
          const SectionHeader('मुख्य वित्तीय सारांश', Icons.bar_chart),
          StatGrid(summaryCards(s)),
          if (s.canWrite) ...[
            const SectionHeader('कार्य', Icons.edit_note),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final f in forms)
                  RaisedCard(
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => f.$3)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(f.$2, color: p.primary, size: 30),
                      const SizedBox(height: 6),
                      Text(f.$1, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: p.deep)),
                    ]),
                  ),
              ],
            ),
          ],
          const SectionHeader('हाल की गतिविधियाँ', Icons.history),
          if (recent.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('अभी कोई गतिविधि नहीं', style: TextStyle(color: p.textSecondary))),
          for (final r in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RaisedCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.$2, style: TextStyle(fontWeight: FontWeight.w700, color: p.deep)),
                      Text('${fd(r.$1)}  •  ${r.$3}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ]),
                  ),
                  Text(rs(r.$4), style: TextStyle(fontWeight: FontWeight.w800, color: p.primary)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    void go(Widget w) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    }
    final items = <(IconData, String, VoidCallback)>[
      (Icons.dashboard, 'डैशबोर्ड', () => go(const DashboardScreen())),
      (Icons.groups, 'सदस्य सूची', () => go(const MembersScreen())),
      (Icons.calendar_month, 'मासिक जमा सूची', () => go(const JamaListScreen())),
      (Icons.request_quote, 'उधार सूची', () => go(const UdharListScreen())),
      (Icons.description, 'स्टेटमेंट', () => go(const StatementScreen())),
      (Icons.receipt_long, 'खर्च और अतिरिक्त राशि की सूची', () => go(const KharchAtiriktScreen())),
      (Icons.payments, 'वितरण राशि की सूची', () => go(const VitranListScreen())),
      (Icons.picture_as_pdf, 'हर member का जमा सूची PDF', () => go(const MemberJamaScreen())),
      (Icons.settings, 'सेटिंग', () => go(const SettingsScreen())),
      (Icons.logout, 'लॉगआउट', () async {
        Navigator.pop(context);
        if (await confirm(context, 'क्या आप लॉगआउट करना चाहते हैं?')) s.logout();
      }),
    ];
    return Drawer(
      backgroundColor: p.background,
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
          color: p.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: p.mint, child: Icon(Icons.groups, color: AppPalette.light.primary)),
              const SizedBox(width: 10),
              const Expanded(child: Text('हमारी चिट फंड फैमिली 2.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 14),
            Text(s.myName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text(s.role, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        for (final i in items) ListTile(leading: Icon(i.$1, color: p.primary), title: Text(i.$2, style: TextStyle(color: p.text, fontWeight: FontWeight.w600)), onTap: i.$3),
      ]),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    final (cat, total) = s.categoryTable();
    Widget cell(String t, {bool b = false}) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3), child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: b ? FontWeight.w800 : FontWeight.w500))));
    return AppScaffold(
      title: 'डैशबोर्ड',
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        const SectionHeader('मुख्य वित्तीय सारांश', Icons.bar_chart),
        StatGrid(summaryCards(s)),
        const SectionHeader('ऋण धारक एवं श्रेणीवार विवरण', Icons.groups),
        RaisedCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Container(
              decoration: BoxDecoration(color: p.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
              child: Row(children: [for (final h in ['श्रेणी', 'दर', 'संख्या', 'उधार', 'ब्याज']) Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text(h, textAlign: TextAlign.center, style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700, fontSize: 12))))]),
            ),
            for (final r in cat) Row(children: [for (final c in r) cell(c)]),
            Container(color: p.mint, child: Row(children: [for (final c in total) cell(c, b: true)])),
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'डैशबोर्ड PDF', icon: Icons.picture_as_pdf, onPressed: () => Rpt.open(context, 'dashboard', () => Reports.dashboard(s))),
      ]),
    );
  }
}
