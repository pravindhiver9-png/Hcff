import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'services/store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Store.I;
    final hasMpin = s.mpin != null && s.memberById(s.mpinUid) != null;
    return MaterialApp(
      title: kGroupName,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: hasMpin ? const MpinLoginScreen() : const LoginScreen(),
    );
  }
}
