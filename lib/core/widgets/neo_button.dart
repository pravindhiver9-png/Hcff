import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NeoButton extends StatelessWidget {
  const NeoButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.check_circle_outline, size: 18),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 0,
    ),
  );
}
