import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class C {
  static const primary = Color(0xFF476B91);
  static const accent = Color(0xFF3E638A);
  static const bg = Color(0xFFE6EEF7);
  static const card = Color(0xFFF7FAFE);
  static const border = Color(0xFFC3D4E6);
  static const text = Color(0xFF1E324B);
  static const text2 = Color(0xFF4B6888);
  static const error = Color(0xFFB91C1C);
  static const ok = Color(0xFF15803D);
}

const kTagline = 'साथ मिलकर, आगे बढ़ें...';
const kGroupName = 'हमारी चिट फंड फैमिली 2.0';

String rs(num v) {
  final f = NumberFormat.decimalPattern('en_IN')..maximumFractionDigits = 2;
  return '₹${f.format(v)}';
}

String dt(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
double num0(String s) => double.tryParse(s.trim()) ?? 0;
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirm(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('नहीं')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('हाँ')),
      ],
    ),
  );
  return r ?? false;
}

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: C.primary, primary: C.primary),
      scaffoldBackgroundColor: C.bg,
      appBarTheme: const AppBarTheme(backgroundColor: C.primary, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(12)});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: padding,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: child,
      );
}

Widget tf(TextEditingController c, String label, {bool number = false, int lines = 1, bool obscure = false, ValueChanged<String>? onChanged}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        onChanged: onChanged,
        obscureText: obscure,
        maxLines: obscure ? 1 : lines,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );

class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DateField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (d != null) onChanged(d);
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(dt(value)),
          ),
        ),
      );
}

Widget btn(String label, VoidCallback? onTap, {IconData icon = Icons.check, Color color = C.accent}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );

class Brand extends StatelessWidget {
  final double size;
  const Brand({super.key, this.size = 80});
  @override
  Widget build(BuildContext context) => Image.asset('assets/images/logo.png', height: size, width: size, errorBuilder: (_, __, ___) => Icon(Icons.groups, size: size, color: C.primary));
}

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text)),
    );
