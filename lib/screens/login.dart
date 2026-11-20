import 'package:flutter/material.dart';
import '../services/store.dart';
import '../ui.dart';
import 'home.dart';

void _goHome(BuildContext c) => Navigator.pushAndRemoveUntil(c, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);

class MpinPad extends StatefulWidget {
  final String title;
  final String? error;
  final ValueChanged<String> onDone;
  const MpinPad({super.key, required this.title, required this.onDone, this.error});
  @override
  State<MpinPad> createState() => _MpinPadState();
}

class _MpinPadState extends State<MpinPad> {
  String pin = '';

  void _tap(String d) {
    if (pin.length >= 4) return;
    setState(() => pin += d);
    if (pin.length == 4) {
      final p = pin;
      widget.onDone(p); // 4th अंक पर अपने-आप सत्यापन
      if (mounted) setState(() => pin = '');
    }
  }

  Widget _key(String label, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 72,
          height: 56,
          child: onTap == null
              ? const SizedBox()
              : OutlinedButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 22, color: C.text))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.text)),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(pin.length > i ? '●' : '_', style: const TextStyle(fontSize: 38, color: C.primary)),
            )),
      ),
      SizedBox(height: 22, child: widget.error == null ? null : Text(widget.error!, style: const TextStyle(color: C.error))),
      const SizedBox(height: 8),
      for (final row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final k in row) _key(k, () => _tap(k))]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _key('', null),
        _key('0', () => _tap('0')),
        Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(width: 72, height: 56, child: IconButton(onPressed: () => setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1)), icon: const Icon(Icons.backspace_outlined))),
        ),
      ]),
    ]);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final id = TextEditingController(), pw = TextEditingController();
  String? err;
  bool hide = true;

  void _login() {
    final m = Store.I.findLogin(id.text, pw.text);
    if (m == null) {
      setState(() => err = 'ID/मोबाइल या पासवर्ड गलत है');
      return;
    }
    Store.I.user = m;
    if (Store.I.mpin != null && Store.I.mpinUid == m.id) {
      _goHome(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MpinCreateScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Brand(size: 110),
                const SizedBox(height: 10),
                const Text(kGroupName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.text)),
                const Text(kTagline, style: TextStyle(color: C.text2)),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    tf(id, 'Login ID / मोबाइल नंबर'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: pw,
                        obscureText: hide,
                        decoration: InputDecoration(labelText: 'पासवर्ड / PIN', suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
                        onSubmitted: (_) => _login(),
                      ),
                    ),
                    if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: C.error))),
                    btn('लॉगिन', _login, icon: Icons.login),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class MpinCreateScreen extends StatefulWidget {
  const MpinCreateScreen({super.key});
  @override
  State<MpinCreateScreen> createState() => _MpinCreateScreenState();
}

class _MpinCreateScreenState extends State<MpinCreateScreen> {
  String? first, err;

  Future<void> _done(String p) async {
    if (first == null) {
      setState(() { first = p; err = null; });
    } else if (first == p) {
      await Store.I.setMpin(p, Store.I.user!.id);
      if (mounted) _goHome(context);
    } else {
      setState(() { first = null; err = 'MPIN मेल नहीं खाया, फिर से बनाएँ'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('MPIN बनाएँ')),
        body: Center(child: MpinPad(key: ValueKey(first), title: first == null ? '4 अंकों का नया MPIN डालें' : 'MPIN दोबारा डालें', error: err, onDone: _done)),
      );
}

class MpinLoginScreen extends StatefulWidget {
  const MpinLoginScreen({super.key});
  @override
  State<MpinLoginScreen> createState() => _MpinLoginScreenState();
}

class _MpinLoginScreenState extends State<MpinLoginScreen> {
  String? err;

  void _done(String p) {
    if (p == Store.I.mpin) {
      Store.I.user = Store.I.memberById(Store.I.mpinUid);
      _goHome(context);
    } else {
      setState(() => err = 'गलत MPIN');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = Store.I.memberById(Store.I.mpinUid);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(children: [
              const Brand(size: 90),
              const SizedBox(height: 8),
              Text('नमस्ते, ${m?.name ?? ''}', style: const TextStyle(fontSize: 18, color: C.text)),
              const SizedBox(height: 20),
              MpinPad(title: 'MPIN डालें', error: err, onDone: _done),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('ID और PIN से लॉगिन करें'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
