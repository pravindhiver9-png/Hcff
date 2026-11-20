import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/palette.dart';
import '../core/utils.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

Widget _logo(BuildContext c) {
  final p = c.pal;
  return Column(children: [
    Container(
      width: 90, height: 90,
      decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.border), boxShadow: [
        BoxShadow(color: p.highlight, offset: const Offset(-4, -4), blurRadius: 8),
        BoxShadow(color: p.shadow, offset: const Offset(4, 4), blurRadius: 8),
      ]),
      child: Icon(Icons.groups, size: 52, color: p.primary),
    ),
    const SizedBox(height: 12),
    Text('हमारी चिट फंड फैमिली 2.0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.deep)),
    Text('विश्वास • समृद्धि • सहयोग', style: TextStyle(color: p.textSecondary)),
  ]);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final urlC = TextEditingController(), idC = TextEditingController(), pinC = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    urlC.text = context.read<AppState>().scriptUrl;
  }

  Future<void> go() async {
    final s = context.read<AppState>();
    setState(() => busy = true);
    try {
      await s.saveUrl(urlC.text.trim());
      var id = idC.text.trim();
      final accts = await s.login(id, pinC.text.trim());
      if (accts != null) {
        if (!mounted) return;
        final pick = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('किस खाते के लिए लॉगिन करना है?'),
            children: [
              for (final a in accts)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, a),
                  child: Text('${a['Member_ID']}  -  ${a['Full_Name']}'),
                ),
            ],
          ),
        );
        if (pick == null) return;
        await s.login('${pick['Member_ID']}', pinC.text.trim());
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'लॉगिन',
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const SizedBox(height: 10),
        _logo(context),
        const SizedBox(height: 22),
        RaisedCard(
          child: Column(children: gapped([
            AppField(label: 'Apps Script Web App URL', hint: 'https://script.google.com/macros/s/.../exec', controller: urlC, keyboard: TextInputType.url),
            AppField(label: 'मोबाइल नंबर / Member ID', hint: '10 अंकों का नंबर या HCFF2-01', controller: idC, required: true),
            AppField(label: 'PIN', hint: 'शीट में दिया गया Initial PIN', controller: pinC, keyboard: TextInputType.number, obscure: true, required: true),
            PrimaryButton(label: 'लॉगिन करें', icon: Icons.login, onPressed: go, busy: busy),
          ])),
        ),
      ]),
    );
  }
}

class MpinScreen extends StatefulWidget {
  const MpinScreen({super.key});
  @override
  State<MpinScreen> createState() => _MpinState();
}

class _MpinState extends State<MpinScreen> {
  final a = TextEditingController(), b = TextEditingController();
  String? err;

  void go() {
    final s = context.read<AppState>();
    if (s.mpinHash.isEmpty) {
      if (a.text.length != 4) { setState(() => err = '4 अंकों का mPIN लिखें'); return; }
      if (a.text != b.text) { setState(() => err = 'दोनों mPIN एक जैसे नहीं हैं'); return; }
      s.setMpin(a.text);
    } else {
      if (s.checkMpin(a.text)) {
        s.unlock();
      } else {
        setState(() => err = 'mPIN गलत है');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final setMode = s.mpinHash.isEmpty;
    return AppScaffold(
      title: setMode ? 'mPIN सेट करें' : 'mPIN दर्ज करें',
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const SizedBox(height: 10),
        _logo(context),
        const SizedBox(height: 22),
        RaisedCard(
          child: Column(children: gapped([
            if (s.myName.isNotEmpty) Text('नमस्ते, ${s.myName}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.pal.deep)),
            AppField(label: setMode ? 'नया 4 अंकों का mPIN' : 'mPIN', controller: a, keyboard: TextInputType.number, obscure: true, maxLength: 4),
            if (setMode) AppField(label: 'mPIN दोबारा लिखें', controller: b, keyboard: TextInputType.number, obscure: true, maxLength: 4),
            if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
            PrimaryButton(label: setMode ? 'सहेजें' : 'खोलें', icon: Icons.lock_open, onPressed: go),
            if (!setMode) SecondaryButton(label: 'दूसरे खाते से लॉगिन', icon: Icons.logout, onPressed: s.logout),
          ])),
        ),
      ]),
    );
  }
}
