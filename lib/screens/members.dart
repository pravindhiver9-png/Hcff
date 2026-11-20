import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/store.dart';
import '../ui.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final s = Store.I;

  Future<void> _edit([Member? m]) async {
    final name = TextEditingController(text: m?.name ?? '');
    final mobile = TextEditingController(text: m?.mobile ?? '');
    final login = TextEditingController(text: m?.loginId ?? '');
    final pw = TextEditingController(text: m?.password ?? '');
    var role = m?.role ?? 'member';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(m == null ? 'नया सदस्य' : 'सदस्य बदलें'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              tf(name, 'नाम'),
              tf(mobile, 'मोबाइल नंबर', number: true),
              tf(login, 'Login ID'),
              tf(pw, 'पासवर्ड / PIN'),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'भूमिका'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'coadmin', child: Text('Co-Admin')),
                  DropdownMenuItem(value: 'member', child: Text('Member (सिर्फ़ देखें)')),
                ],
                onChanged: (v) => set(() => role = v ?? 'member'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('रद्द')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('सेव')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || login.text.trim().isEmpty || pw.text.isEmpty) {
      if (mounted) toast(context, 'नाम, Login ID और पासवर्ड ज़रूरी हैं');
      return;
    }
    if (m == null) {
      s.members.add(Member(id: s.newId(), name: name.text.trim(), mobile: mobile.text.trim(), loginId: login.text.trim(), password: pw.text, role: role));
    } else {
      m.name = name.text.trim();
      m.mobile = mobile.text.trim();
      m.loginId = login.text.trim();
      m.password = pw.text;
      m.role = role;
    }
    await s.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fe = s.fe;
    return Scaffold(
      appBar: AppBar(title: const Text('सदस्य सूची')),
      floatingActionButton: s.isAdmin ? FloatingActionButton(onPressed: _edit, child: const Icon(Icons.person_add)) : null,
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final m in s.members)
          AppCard(
            child: Row(children: [
              const CircleAvatar(backgroundColor: C.primary, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                Text('${m.roleLabel} • ${m.mobile}', style: const TextStyle(fontSize: 12, color: C.text2)),
                Text('कुल जमा ${rs(fe.memberJama(m.id))}', style: const TextStyle(fontSize: 12, color: C.text2)),
              ])),
              if (s.isAdmin) ...[
                IconButton(icon: const Icon(Icons.edit, color: C.accent), onPressed: () => _edit(m)),
                if (m.id != s.user?.id)
                  IconButton(
                    icon: const Icon(Icons.delete, color: C.error),
                    onPressed: () async {
                      final used = s.loans.any((l) => l.memberId == m.id) || s.jama.any((j) => j.memberId == m.id) || s.vitran.any((v) => v.memberId == m.id);
                      if (used) { toast(context, 'इस सदस्य की एंट्रियाँ मौजूद हैं, हटाया नहीं जा सकता'); return; }
                      if (await confirm(context, '${m.name} को हटाएँ?')) {
                        s.members.remove(m);
                        await s.save();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
              ],
            ]),
          ),
      ]),
    );
  }
}
