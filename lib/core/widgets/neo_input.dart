import 'package:flutter/material.dart';

class NeoInput extends StatelessWidget {
  const NeoInput({super.key, required this.label, this.controller, this.keyboardType});
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
  );
}
