import 'package:flutter/material.dart';

/// Central colour tokens. Light = approved palette. Dark = tokens chosen here
/// (matte black + white + green accents) because the spec left them open.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.isDark,
    required this.background,
    required this.primary,
    required this.deep,
    required this.darkGreen,
    required this.sage,
    required this.softSage,
    required this.mint,
    required this.input,
    required this.card,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.highlight,
    required this.shadow,
    required this.onPrimary,
  });

  final bool isDark;
  final Color background, primary, deep, darkGreen, sage, softSage, mint, input,
      card, border, text, textSecondary, highlight, shadow, onPrimary;

  Color get accent => isDark ? deep : primary;

  // status / value colours (used for figures on cards)
  static const blue = Color(0xFF1565C0);
  static const amber = Color(0xFFE07B00);
  static const red = Color(0xFFC62828);
  static const violet = Color(0xFF4B3FA8);

  static const light = AppPalette(
    isDark: false,
    background: Color(0xFFF2F5F2),
    primary: Color(0xFF1C5238),
    deep: Color(0xFF133D29),
    darkGreen: Color(0xFF285841),
    sage: Color(0xFF5F8E77),
    softSage: Color(0xFF95ADA0),
    mint: Color(0xFFE6EFE9),
    input: Color(0xFFF7F8F6),
    card: Color(0xFFE0EAE3),
    border: Color(0xFFC0D1C7),
    text: Color(0xFF1C1C1C),
    textSecondary: Color(0xFF808784),
    highlight: Color(0xCCFFFFFF),
    shadow: Color(0x66A3B8AA),
    onPrimary: Colors.white,
  );

  static const dark = AppPalette(
    isDark: true,
    background: Color(0xFF101210),
    primary: Color(0xFF2F7A55),
    deep: Color(0xFFA9D8BD),
    darkGreen: Color(0xFF3A6B52),
    sage: Color(0xFF7FB096),
    softSage: Color(0xFF95ADA0),
    mint: Color(0xFF202622),
    input: Color(0xFF151815),
    card: Color(0xFF1A1E1B),
    border: Color(0xFF2C352F),
    text: Color(0xFFF2F5F2),
    textSecondary: Color(0xFF9AA39E),
    highlight: Color(0x0DFFFFFF),
    shadow: Color(0x99000000),
    onPrimary: Colors.white,
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      other is AppPalette ? (t < 0.5 ? this : other) : this;
}

extension PaletteX on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
}
