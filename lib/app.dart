import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';

class ChitFundApp extends StatelessWidget {
  const ChitFundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'हमारी चिट फण्ड फैमिली 2.0',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
