import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  late final TextEditingController jamaC, memC, nonC, startC;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    jamaC = TextEditingController(text: ns(s.monthly));
    memC = TextEditingController(text: ns(s.memberRate));
    nonC = TextEditingController(text: ns(s.nonMemberRate));
    startC = TextEditingController(text: '${s.settings['Group_Start'] ?? '2025-02'}'.substring(0, 7));
  }

  Future<void> _saveSettings() async {
    final s = context.read<AppState>();
    setState(() => busy = true);
    try {
      await s.saveSettings({'Monthly_Jama': toNum(jamaC.text), 'Member_Rate': toNum(memC.text), 'NonMember_Rate': toNum(nonC.text), 'Group_Start': startC.text.trim()});
      if (mounted) toast(context, 'सेटिंग सहेज ली गई');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _changeMpin() async {
    final s = context.read<AppState>();
    final o = TextEditingController(), n = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('mPIN बदलें'),
        content: Column(mainAxisSize: MainAxisSize.min, children: gapped([
          AppField(label: 'पुराना mPIN', controller: o, keyboard: TextInputType.number, obscure: true, maxLength: 4),
          AppField(label: 'नया mPIN', controller: n, keyboard: TextInputType.number, obscure: true, maxLength: 4),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('रद्द करें')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('बदलें')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!s.checkMpin(o.text)) { toast(context, 'पुराना mPIN गलत है'); return; }
    if (n.text.length != 4) { toast(context, '4 अंकों का mPIN लिखें'); return; }
    await s.setMpin(n.text);
    if (mounted) toast(context, 'mPIN बदल गया');
  }

  Future<void> _backup() async {
    final s = context.read<AppState>();
    try {
      final r = await s.call('backup');
      if (mounted) toast(context, 'बैकअप बन गया: ${r['name']}');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _restore() async {
    final s = context.read<AppState>();
    try {
      final r = await s.call('listBackups');
      final list = (r['backups'] as List).map((e) => Map<String, dynamic>.from(e)).toList().reversed.toList();
      if (!mounted) return;
      if (list.isEmpty) { toast(context, 'कोई बैकअप नहीं मिला'); return; }
      final pick = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('कौन सा बैकअप रिस्टोर करें?'),
          children: [for (final b in list) SimpleDialogOption(onPressed: () => Navigator.pop(c, b), child: Text('${b['name']}'))],
        ),
      );
      if (pick == null || !mounted) return;
      if (!await confirm(context, 'मौजूदा डेटा इस बैकअप से बदल जाएगा। जारी रखें?', yes: 'रिस्टोर करें')) return;
      await s.call('restore', {'id': pick['id']});
      await s.refresh();
      if (mounted) toast(context, 'रिस्टोर पूरा हुआ');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return AppScaffold(
      title: 'सेटिंग',
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        if (s.canWrite) ...[
          const SectionHeader('समूह सेटिंग', Icons.tune),
          RaisedCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
              AppField(label: 'मासिक जमा राशि (₹)', controller: jamaC, keyboard: numKb),
              AppField(label: 'सदस्य ब्याज दर (% प्रति माह)', controller: memC, keyboard: numKb),
              AppField(label: 'गैर-सदस्य ब्याज दर (% प्रति माह)', controller: nonC, keyboard: numKb),
              AppField(label: 'समूह शुरुआत (YYYY-MM)', controller: startC),
              PrimaryButton(label: 'सहेजें', icon: Icons.save, onPressed: _saveSettings, busy: busy),
            ])),
          ),
        ],
        const SectionHeader('सुरक्षा और दिखावट', Icons.security),
        RaisedCard(
          child: Column(children: gapped([
            SecondaryButton(label: 'mPIN बदलें', icon: Icons.pin, onPressed: _changeMpin),
            SwitchListTile(title: const Text('डार्क थीम'), value: s.dark, onChanged: s.setDark),
            AppDropdown<String>(label: 'भाषा / Language', value: s.lang, items: const ['hi', 'en'], labelOf: (e) => e == 'hi' ? 'हिन्दी' : 'English', onChanged: (v) => s.setLang(v ?? 'hi')),
            AppField(label: 'Apps Script URL', controller: TextEditingController(text: s.scriptUrl), onChanged: (v) => s.saveUrl(v.trim())),
          ])),
        ),
        if (s.canWrite) ...[
          const SectionHeader('बैकअप / रिस्टोर', Icons.backup),
          RaisedCard(
            child: Row(children: [
              Expanded(child: SecondaryButton(label: 'बैकअप', icon: Icons.cloud_upload, onPressed: _backup)),
              const SizedBox(width: 10),
              Expanded(child: SecondaryButton(label: 'रिस्टोर', icon: Icons.cloud_download, onPressed: _restore)),
            ]),
          ),
        ],
      ]),
    );
  }
}
