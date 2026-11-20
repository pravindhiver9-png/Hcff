import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

class NeoCard extends StatelessWidget {
  const NeoCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dark ? const Color(0xFF405448) : AppColors.border),
          boxShadow: dark ? AppShadows.raisedDark : AppShadows.raised,
        ),
        child: child,
      ),
    );
  }
}
