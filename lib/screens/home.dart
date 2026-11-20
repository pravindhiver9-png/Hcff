import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';
import 'jama_wapsi.dart';
import 'kharch_atirikt.dart';
import 'login.dart';
import 'masik_jama.dart';
import 'members.dart';
import 'paisa_vitran.dart';
import 'udhar_entry.dart';
import 'udhar_list.dart';

class _Act {
  final DateTime date;
  final String title;
  final double amt;
  final bool plus;
  _Act(this.date, this.title, this.amt, this.plus);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final s = Store.I;
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    s.addListener(_r);
  }

  @override
  void dispose() {
    s.removeListener(_r);
    super.dispose();
  }

  void _go(Widget w, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }

  Widget _sum(String t, double v, IconData i) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Row(children: [
          Icon(i, color: C.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 12, color: C.text2)),
              FittedBox(fit: BoxFit.scaleDown, child: Text(rs(v), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: C.text))),
            ]),
          ),
        ]),
      );

  Widget _act(String t, IconData i, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, color: C.accent, size: 28),
            const SizedBox(height: 4),
            Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.text)),
          ]),
        ),
      );

  List<_Act> _recent() {
    final a = <_Act>[
      for (final l in s.loans.where((l) => l.parentId == null)) _Act(l.date, 'उधार — ${l.borrower}', l.principal, false),
      for (final l in s.loans.where((l) => l.repayDate != null)) _Act(l.repayDate!, 'जमा वापसी — ${l.borrower}', l.interestPaid + l.principalPaid, true),
      for (final j in s.jama) _Act(j.date, 'मासिक जमा — ${s.memberById(j.memberId)?.name ?? ''} (${j.month})', j.amount, true),
      for (final k in s.kharch) _Act(k.date, 'खर्च${k.note.isEmpty ? '' : ' — ${k.note}'}', k.amount, false),
      for (final k in s.atirikt) _Act(k.date, 'अतिरिक्त राशि${k.note.isEmpty ? '' : ' — ${k.note}'}', k.amount, true),
      for (final v in s.vitran) _Act(v.date, 'पैसा वितरण — ${s.memberById(v.memberId)?.name ?? ''}', v.share, false),
    ]..sort((x, y) => y.date.compareTo(x.date));
    return a.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fe = s.fe;
    final u = s.user;
    final edit = s.canEdit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('डैशबोर्ड'),
        actions: [
          Icon(s.sheetUrl.isEmpty ? Icons.cloud_off : (s.pending ? Icons.cloud_upload : Icons.cloud_done), size: 20),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _go(const SettingsScreen())),
        ],
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: C.primary),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              const Brand(size: 52),
              const SizedBox(height: 6),
              const Text(kGroupName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${u?.name ?? ''} • ${u?.roleLabel ?? ''}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text('डैशबोर्ड'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.groups), title: const Text('सदस्य सूची'), onTap: () => _go(const MembersScreen(), closeDrawer: true)),
          ListTile(leading: const Icon(Icons.calendar_month), title: const Text('मासिक जमा रजिस्टर'), onTap: () => _go(const MasikJamaScreen(), closeDrawer: true)),
          ListTile(leading: const Icon(Icons.account_balance), title: const Text('उधार खाता'), onTap: () => _go(const UdharListScreen(), closeDrawer: true)),
          ListTile(leading: const Icon(Icons.history), title: const Text('जमा वापसी इतिहास'), onTap: () => _go(const JamaWapsiHistoryScreen(), closeDrawer: true)),
          ListTile(leading: const Icon(Icons.receipt_long), title: const Text('खर्च और अतिरिक्त रजिस्टर'), onTap: () => _go(const KharchAtiriktScreen(), closeDrawer: true)),
          ListTile(leading: const Icon(Icons.share), title: const Text('पैसा वितरण रजिस्टर'), onTap: () => _go(const PaisaVitranScreen(), closeDrawer: true)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('लॉगआउट / MPIN रीसेट'),
            onTap: () async {
              Navigator.pop(context);
              final reset = await showDialog<String>(
                context: context,
                builder: (c) => SimpleDialog(title: const Text('लॉगआउट'), children: [
                  SimpleDialogOption(onPressed: () => Navigator.pop(c, 'out'), child: const Text('सिर्फ़ लॉगआउट (MPIN रखें)')),
                  SimpleDialogOption(onPressed: () => Navigator.pop(c, 'reset'), child: const Text('MPIN रीसेट करके लॉगआउट')),
                ]),
              );
              if (reset == null || !mounted) return;
              if (reset == 'reset') await s.clearMpin();
              s.user = null;
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => s.mpin != null ? const MpinLoginScreen() : const LoginScreen()),
                (r) => false,
              );
            },
          ),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.primary, C.accent]), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Brand(size: 56)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(kGroupName, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text(kTagline, style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  Flexible(child: Text(u?.name ?? '', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: Text(u?.roleLabel ?? '', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            _sum('कुल फंड', fe.totalFund, Icons.account_balance_wallet),
            _sum('कुल जमा', fe.kulJama, Icons.savings),
            _sum('कुल ब्याज', fe.kulByaj, Icons.trending_up),
            _sum('सक्रिय उधार', fe.sakriyUdhar, Icons.currency_rupee),
            _sum('खर्च', fe.kulKharch, Icons.shopping_cart),
            _sum('पैसा वितरण', fe.kulVitran, Icons.share),
          ],
        ),
        if (edit) ...[
          sectionTitle('कार्य'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              _act('उधार एंट्री', Icons.north_east, () => _go(const UdharEntryScreen())),
              _act('जमा वापसी', Icons.south_west, () => _go(const JamaWapsiScreen())),
              _act('मासिक जमा', Icons.calendar_month, () => _go(const MasikJamaScreen())),
              _act('खर्च', Icons.shopping_cart, () => _go(const KharchAtiriktScreen(initialTab: 0))),
              _act('अतिरिक्त राशि', Icons.add_circle_outline, () => _go(const KharchAtiriktScreen(initialTab: 1))),
              _act('उधार लिस्ट', Icons.list_alt, () => _go(const UdharListScreen())),
              if (s.isAdmin) _act('पैसा वितरण', Icons.share, () => _go(const PaisaVitranScreen())),
            ],
          ),
        ] else ...[
          sectionTitle('देखें'),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('उधार लिस्ट'), onPressed: () => _go(const UdharListScreen())),
            ActionChip(label: const Text('मासिक जमा'), onPressed: () => _go(const MasikJamaScreen())),
          ]),
        ],
        sectionTitle('हाल की गतिविधि'),
        if (_recent().isEmpty) const AppCard(child: Text('अभी कोई एंट्री नहीं है', style: TextStyle(color: C.text2))),
        for (final a in _recent())
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: const TextStyle(color: C.text)),
                Text(dt(a.date), style: const TextStyle(fontSize: 11, color: C.text2)),
              ])),
              Text('${a.plus ? '+' : '−'} ${rs(a.amt)}', style: TextStyle(fontWeight: FontWeight.bold, color: a.plus ? C.ok : C.error)),
            ]),
          ),
      ]),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = Store.I;
  late final monthly = TextEditingController(text: s.monthlyAmount.toStringAsFixed(0));
  late final mRate = TextEditingController(text: s.memberRate.toString());
  late final oRate = TextEditingController(text: s.outsiderRate.toString());
  late final url = TextEditingController(text: s.sheetUrl);

  @override
  Widget build(BuildContext context) {
    final admin = s.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('सेटिंग्स')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        AppCard(child: Column(children: [
          if (!admin) const Text('सेटिंग्स सिर्फ़ Admin बदल सकता है', style: TextStyle(color: C.text2)),
          tf(monthly, 'मासिक जमा (₹ प्रति सदस्य)', number: true),
          tf(mRate, 'सदस्य ब्याज दर (% प्रति माह)', number: true),
          tf(oRate, 'बाहरी ब्याज दर (% प्रति माह)', number: true),
          tf(url, 'Google Apps Script Web App URL'),
          if (admin)
            btn('सेटिंग्स सेव करें', () async {
              s.monthlyAmount = num0(monthly.text) <= 0 ? 200 : num0(monthly.text);
              s.memberRate = num0(mRate.text);
              s.outsiderRate = num0(oRate.text);
              await s.setSheetUrl(url.text);
              await s.save();
              if (mounted) toast(context, 'सेव हो गया');
            }),
        ])),
        AppCard(child: Column(children: [
          Text(s.sheetUrl.isEmpty ? 'शीट बैकअप बंद है' : (s.pending ? 'सिंक बाकी है (नेट आने पर अपने-आप होगा)' : 'शीट के साथ सिंक ✓'), style: const TextStyle(color: C.text2)),
          const SizedBox(height: 8),
          btn('अभी शीट में बैकअप करें', () async {
            await s.setSheetUrl(url.text);
            await s.sync();
            if (mounted) { setState(() {}); toast(context, s.pending ? 'बैकअप नहीं हो सका' : 'बैकअप हो गया ✓'); }
          }, icon: Icons.cloud_upload),
          if (admin)
            btn('शीट से रीस्टोर करें', () async {
              if (!await confirm(context, 'मौजूदा डेटा शीट के डेटा से बदल जाएगा। जारी रखें?')) return;
              await s.setSheetUrl(url.text);
              final m = await s.restoreFromSheet();
              if (mounted) toast(context, m);
            }, icon: Icons.cloud_download, color: C.primary),
        ])),
      ]),
    );
  }
}
