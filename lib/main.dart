import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final s = AppState();
  await s.init();
  runApp(ChangeNotifierProvider.value(value: s, child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'हमारी चिट फंड फैमिली 2.0',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(false),
      darkTheme: AppTheme.build(true),
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(s.lang),
      supportedLocales: const [Locale('hi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: !s.hasLogin ? const LoginScreen() : (!s.unlocked ? const MpinScreen() : const HomeScreen()),
    );
  }
}
