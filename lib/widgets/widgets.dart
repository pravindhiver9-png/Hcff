import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// Screen frame: app background image (light theme) + transparent app bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.title, required this.body, this.actions, this.drawer, this.bottom});
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final top = MediaQuery.of(context).padding.top + kToolbarHeight + (bottom?.preferredSize.height ?? 0);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: p.background,
      drawer: drawer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.deep,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: actions,
        bottom: bottom,
      ),
      body: Stack(fit: StackFit.expand, children: [
        if (!p.isDark) Image.asset('assets/images/app_background.png', fit: BoxFit.cover),
        Padding(padding: EdgeInsets.only(top: top), child: body),
      ]),
    );
  }
}

/// Four-side raised neomorphic card.
class RaisedCard extends StatelessWidget {
  const RaisedCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppTheme.pad), this.onTap, this.color, this.radius = AppTheme.radius});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(color: p.highlight, offset: const Offset(-4, -4), blurRadius: 8), // upper-left light
          BoxShadow(color: p.shadow, offset: const Offset(4, 4), blurRadius: 8), // lower-right shadow
          BoxShadow(color: p.shadow.withOpacity(0.3), blurRadius: 14), // ambient
        ],
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: p.shadow, offset: const Offset(3, 4), blurRadius: 8),
        BoxShadow(color: p.highlight, offset: const Offset(-3, -3), blurRadius: 6),
      ]),
      child: Material(
        color: p.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else if (icon != null)
                Icon(icon, color: p.onPrimary),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.onPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.icon, this.onPressed});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return RaisedCard(
      color: p.input,
      onTap: onPressed,
      radius: 16,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) Icon(icon, color: p.accent, size: 20),
        if (icon != null) const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 14.5))),
      ]),
    );
  }
}

InputDecoration _deco(BuildContext c, {String? hint, Widget? suffix, bool auto = false}) {
  final p = c.pal;
  OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.fieldRadius), borderSide: BorderSide(color: col, width: w));
  return InputDecoration(
    isDense: true,
    counterText: '',
    hintText: hint,
    hintStyle: TextStyle(color: p.textSecondary),
    suffixIcon: suffix,
    filled: true,
    fillColor: auto ? p.card : p.input,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: b(p.border),
    enabledBorder: b(p.border),
    focusedBorder: b(p.primary, 1.6),
  );
}

Widget _label(BuildContext c, String label, bool required) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(
        text: label,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: c.pal.deep),
        children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
      )),
    );

class AppField extends StatelessWidget {
  const AppField({super.key, required this.label, this.hint, this.controller, this.keyboard, this.readOnly = false, this.onTap, this.suffix, this.onChanged, this.focusNode, this.auto = false, this.required = false, this.maxLength, this.obscure = false});
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboard;
  final bool readOnly, auto, required, obscure;
  final VoidCallback? onTap;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(context, label, required),
      TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        readOnly: readOnly || auto,
        onTap: onTap,
        onChanged: onChanged,
        maxLength: maxLength,
        obscureText: obscure,
        inputFormatters: keyboard == TextInputType.number || keyboard == const TextInputType.numberWithOptions(decimal: true)
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        style: TextStyle(color: p.text, fontSize: 15, fontWeight: auto ? FontWeight.w700 : FontWeight.w500),
        decoration: _deco(context, hint: hint, suffix: suffix, auto: auto),
      ),
    ]);
  }
}

const numKb = TextInputType.numberWithOptions(decimal: true);

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.required = false});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(context, label, required),
      TextFormField(
        key: ValueKey(value?.toIso8601String()),
        initialValue: fd(value),
        readOnly: true,
        style: TextStyle(color: p.text, fontSize: 15),
        decoration: _deco(context, suffix: Icon(Icons.calendar_month, color: p.accent)),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (d != null) onChanged(d);
        },
      ),
    ]);
  }
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({super.key, required this.label, required this.value, required this.items, required this.labelOf, required this.onChanged, this.hint, this.required = false});
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(context, label, required),
      DropdownButtonFormField<T>(
        value: items.contains(value) ? value : null,
        isExpanded: true,
        dropdownColor: p.card,
        icon: Icon(Icons.keyboard_arrow_down, color: p.accent),
        hint: hint == null ? null : Text(hint!, style: TextStyle(color: p.textSecondary)),
        items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(labelOf(e), overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text)))).toList(),
        onChanged: onChanged,
        decoration: _deco(context),
      ),
    ]);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: p.shadow, offset: const Offset(2, 3), blurRadius: 6)],
      ),
      child: Row(children: [
        Icon(icon, color: p.onPrimary),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.title, required this.value, this.note, this.color});
  final IconData icon;
  final String title, value;
  final String? note;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return RaisedCard(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Icon(icon, color: p.sage, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color ?? p.deep))),
            if (note != null) Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: p.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class StatGrid extends StatelessWidget {
  const StatGrid(this.cards, {super.key});
  final List<StatCard> cards;
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.0,
        children: cards,
      );
}

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});
  final String role;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(20)),
      child: Text(role, style: TextStyle(color: p.onPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

List<Widget> gapped(List<Widget> c, [double h = AppTheme.gap]) =>
    [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: h), c[i]]];

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

Future<bool> confirm(BuildContext c, String msg, {String yes = 'हाँ'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (x) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('रद्द करें')),
        FilledButton(onPressed: () => Navigator.pop(x, true), child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

/// Auto-generated WhatsApp group message: Copy & Share.
Future<void> showWa(BuildContext c, String text) => showDialog(
      context: c,
      builder: (x) => AlertDialog(
        title: const Text('WhatsApp संदेश'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () { Clipboard.setData(ClipboardData(text: text)); toast(x, 'कॉपी हो गया'); },
            child: const Text('कॉपी'),
          ),
          TextButton(onPressed: () => Share.share(text), child: const Text('शेयर')),
          FilledButton(onPressed: () => Navigator.pop(x), child: const Text('ठीक है')),
        ],
      ),
    );
