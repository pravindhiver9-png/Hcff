import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'palette.dart';

class AppTheme {
  // shared shape / spacing constants
  static const double radius = 18;
  static const double fieldRadius = 14;
  static const double gap = 12;
  static const double pad = 14;

  static ThemeData build(bool dark) {
    final p = dark ? AppPalette.dark : AppPalette.light;
    final b = dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: b)
        .copyWith(primary: p.primary, onPrimary: p.onPrimary, surface: p.card, onSurface: p.text);
    final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      textTheme: GoogleFonts.notoSansDevanagariTextTheme(base.textTheme)
          .apply(bodyColor: p.text, displayColor: p.text),
      extensions: [p],
    );
  }
}
