import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/palette.dart';
import '../core/utils.dart';
import '../pdf/pdf_service.dart';
import '../pdf/reports.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

class Fld {
  const Fld(this.key, this.label, {this.type = 'text', this.opts});
  final String key, label;
  final String type; // text | num | date
  final List<String>? opts;
}

/// Generic list body: search-free, edit/delete for Admin/Co-Admin, optional PDF + status filter.
class RecordList extends StatefulWidget {
  const RecordList({
    super.key, required this.sheet, required this.fields, required this.title, required this.sub, required this.trail,
    this.statusKey, this.canAdd = false, this.addDefaults = const {}, this.onPdf, this.pdfLabel = 'PDF',
  });
  final String sheet;
  final List<Fld> fields;
  final String Function(Map<String, dynamic>) title, sub, trail;
  final String? statusKey;
  final bool canAdd;
  final Map<String, dynamic> addDefaults;
  final void Function(List<Map<String, dynamic>> rows, String filter)? onPdf;
  final String pdfLabel;
  @override
  State<RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<RecordList> {
  String filter = 'सभी';

  Future<void> _edit(Map<String, dynamic>? row) async {
    final s = context.read<AppState>();
    final ctrls = {
      for (final f in widget.fields) f.key: TextEditingController(text: '${(row ?? widget.addDefaults)[f.key] ?? ''}')
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(row == null ? 'नया जोड़ें' : 'संपादित करें'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: gapped([
                for (final f in widget.fields)
                  if (f.opts != null)
                    AppDropdown<String>(label: f.label, value: ctrls[f.key]!.text, items: f.opts!, labelOf: (e) => e, onChanged: (v) => set(() => ctrls[f.key]!.text = v ?? ''))
                  else if (f.type == 'date')
                    DateField(label: f.label, value: pd(ctrls[f.key]!.text), onChanged: (d) => set(() => ctrls[f.key]!.text = iso(d)))
                  else
                    AppField(label: f.label, controller: ctrls[f.key], keyboard: f.type == 'num' ? numKb : null),
              ], 10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('रद्द करें')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('सहेजें')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final data = {for (final f in widget.fields) f.key: f.type == 'num' ? toNum(ctrls[f.key]!.text) : ctrls[f.key]!.text.trim()};
    try {
      await s.batch([
        row == null
            ? {'op': 'add', 'sheet': widget.sheet, 'row': data}
            : {'op': 'update', 'sheet': widget.sheet, 'id': row[kIdKey[widget.sheet]], 'row': data}
      ]);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirm(context, 'क्या आप यह रिकॉर्ड हटाना चाहते हैं?', yes: 'हटाएँ')) return;
    try {
      await context.read<AppState>().batch([{'op': 'delete', 'sheet': widget.sheet, 'id': row[kIdKey[widget.sheet]]}]);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    var rows = s.rows(widget.sheet);
    if (widget.statusKey != null && filter != 'सभी') rows = rows.where((r) => '${r[widget.statusKey]}' == filter).toList();
    rows = rows.reversed.toList();
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
      if (widget.statusKey != null)
        Wrap(spacing: 8, children: [
          for (final f in ['सभी', 'सक्रिय', 'पूर्ण जमा'])
            ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
        ]),
      Row(children: [
        if (widget.onPdf != null) Expanded(child: SecondaryButton(label: widget.pdfLabel, icon: Icons.picture_as_pdf, onPressed: () => widget.onPdf!(rows.reversed.toList(), filter))),
        if (widget.onPdf != null && widget.canAdd && s.canWrite) const SizedBox(width: 10),
        if (widget.canAdd && s.canWrite) Expanded(child: PrimaryButton(label: 'नया जोड़ें', icon: Icons.add, onPressed: () => _edit(null))),
      ]),
      const SizedBox(height: 10),
      if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('कोई रिकॉर्ड नहीं', style: TextStyle(color: p.textSecondary)))),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RaisedCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title(r), style: TextStyle(fontWeight: FontWeight.w800, color: p.deep)),
                  Text(widget.sub(r), style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ]),
              ),
              Text(widget.trail(r), style: TextStyle(fontWeight: FontWeight.w800, color: p.primary)),
              if (s.canWrite) ...[
                IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.edit, size: 20, color: p.sage), onPressed: () => _edit(r)),
                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 20, color: AppPalette.red), onPressed: () => _delete(r)),
              ] else
                const SizedBox(width: 8),
            ]),
          ),
        ),
    ]);
  }
}

// ---------------- सदस्य सूची ----------------
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'सदस्य सूची',
        body: RecordList(
          sheet: 'Members',
          canAdd: true,
          addDefaults: const {'Role': 'Member', 'Status': 'सक्रिय', 'Initial_PIN': '1234'},
          fields: const [
            Fld('First_Name', 'नाम'),
            Fld('Surname', 'उपनाम / सरनेम'),
            Fld('Mobile_No', 'मोबाइल नंबर (वैकल्पिक)'),
            Fld('Initial_PIN', 'Initial PIN'),
            Fld('Role', 'भूमिका', opts: ['Admin', 'Co-Admin', 'Member']),
            Fld('Status', 'स्थिति', opts: ['सक्रिय', 'निष्क्रिय']),
          ],
          title: (r) => '${r['Full_Name']}',
          sub: (r) => '${r['Member_ID']} • ${r['Role']} • ${r['Status']}${'${r['Mobile_No'] ?? ''}'.isEmpty ? '' : ' • ${r['Mobile_No']}'}',
          trail: (r) => '',
        ),
      );
}

// ---------------- उधार सूची ----------------
class UdharListScreen extends StatelessWidget {
  const UdharListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return AppScaffold(
      title: 'उधार सूची',
      body: RecordList(
        sheet: 'Udhar_Khata',
        statusKey: 'Status',
        pdfLabel: 'PDF बनाएँ',
        onPdf: (rows, f) => Rpt.open(context, 'udhar_suchi', () => Reports.udharList(rows.map(Loan.new).toList(), f)),
        fields: const [
          Fld('Name', 'नाम'),
          Fld('Mobile', 'मोबाइल नंबर'),
          Fld('Principal', 'मूलधन', type: 'num'),
          Fld('Date', 'दिनांक', type: 'date'),
          Fld('Rate', 'ब्याज दर (%)', type: 'num'),
          Fld('Final_Interest', 'अंतिम ब्याज', type: 'num'),
          Fld('Interest_Paid', 'ब्याज जमा', type: 'num'),
          Fld('Principal_Paid', 'मूलधन जमा', type: 'num'),
          Fld('Return_Date', 'जमा दिनांक', type: 'date'),
          Fld('Status', 'स्थिति', opts: ['सक्रिय', 'पूर्ण जमा']),
        ],
        title: (r) => '${r['Name']}',
        sub: (r) => '${fds(r['Date'])} • ${ns(toNum(r['Rate']))}% • ${r['Status']}',
        trail: (r) => rs(toNum(r['Principal'])),
      ),
    );
  }
}

// ---------------- वितरण सूची ----------------
class VitranListScreen extends StatelessWidget {
  const VitranListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return AppScaffold(
      title: 'वितरण राशि की सूची',
      body: RecordList(
        sheet: 'Paisa_Vitran',
        pdfLabel: 'PDF बनाएँ',
        onPdf: (_, __) => Rpt.open(context, 'vitran_suchi', () => Reports.vitran(s)),
        fields: const [
          Fld('Date', 'दिनांक', type: 'date'),
          Fld('Per_Member', 'वितरण राशि', type: 'num'),
          Fld('Adjustment', 'समायोजन', type: 'num'),
          Fld('Final_Amount', 'अंतिम राशि', type: 'num'),
        ],
        title: (r) => '${r['Member_Name']}',
        sub: (r) => '${fds(r['Date'])} • समायोजन ${rs(toNum(r['Adjustment']))}',
        trail: (r) => rs(toNum(r['Final_Amount'])),
      ),
    );
  }
}

// ---------------- खर्च और अतिरिक्त राशि ----------------
class KharchAtiriktScreen extends StatelessWidget {
  const KharchAtiriktScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    void pdf(List<Map<String, dynamic>> _, String __) => Rpt.open(context, 'kharch_atirikt', () => Reports.kharchAtirikt(s));
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'खर्च और अतिरिक्त राशि',
        bottom: const TabBar(tabs: [Tab(text: 'खर्च'), Tab(text: 'अतिरिक्त राशि')]),
        body: TabBarView(children: [
          RecordList(
            sheet: 'Kharch', pdfLabel: 'PDF बनाएँ', onPdf: pdf,
            fields: const [Fld('Date', 'दिनांक', type: 'date'), Fld('Details', 'विवरण'), Fld('Amount', 'राशि', type: 'num')],
            title: (r) => '${r['Details']}', sub: (r) => fds(r['Date']), trail: (r) => rs(toNum(r['Amount'])),
          ),
          RecordList(
            sheet: 'Atirikt_Rashi', pdfLabel: 'PDF बनाएँ', onPdf: pdf,
            fields: const [Fld('Date', 'दिनांक', type: 'date'), Fld('Amount', 'राशि', type: 'num'), Fld('Note', 'नोट')],
            title: (r) => '${r['Note'] ?? 'अतिरिक्त राशि'}', sub: (r) => fds(r['Date']), trail: (r) => rs(toNum(r['Amount'])),
          ),
        ]),
      ),
    );
  }
}

// ---------------- मासिक जमा सूची ----------------
class JamaListScreen extends StatefulWidget {
  const JamaListScreen({super.key});
  @override
  State<JamaListScreen> createState() => _JamaListState();
}

class _JamaListState extends State<JamaListScreen> {
  int year = DateTime.now().year, month = DateTime.now().month;

  Future<void> _editCell(Map<String, dynamic> m, int mo) async {
    final s = context.read<AppState>();
    final c = TextEditingController(text: ns(s.jamaAt('${m['Member_ID']}', year, mo)));
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text('${m['Full_Name']} - ${hiMonths[mo - 1]} $year'),
        content: AppField(label: 'जमा राशि (0 = हटाएँ)', controller: c, keyboard: numKb),
        actions: [
          TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('रद्द करें')),
          FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('सहेजें')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await s.batch([
        {'op': 'saveJama', 'advance': [], 'cells': [{'Member_ID': m['Member_ID'], 'Name': m['Full_Name'], 'Year': year, 'Month': mo, 'Amount': toNum(c.text)}]}
      ]);
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.pal;
    final years = [for (var y = s.groupStart.year; y <= DateTime.now().year + 1; y++) y];
    final ms = s.activeMembers;
    return AppScaffold(
      title: 'मासिक जमा सूची',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(children: gapped([
            Row(children: [
              Expanded(child: AppDropdown<int>(label: 'वर्ष', value: year, items: years, labelOf: (y) => '$y', onChanged: (v) => setState(() => year = v ?? year))),
              const SizedBox(width: 10),
              Expanded(child: AppDropdown<int>(label: 'माह (मासिक PDF)', value: month, items: List.generate(12, (i) => i + 1), labelOf: (m) => hiMonths[m - 1], onChanged: (v) => setState(() => month = v ?? month))),
            ]),
            Row(children: [
              Expanded(child: SecondaryButton(label: 'वार्षिक PDF', icon: Icons.picture_as_pdf, onPressed: () => Rpt.open(context, 'jama_varshik_$year', () => Reports.jamaYearly(s, year)))),
              const SizedBox(width: 10),
              Expanded(child: SecondaryButton(label: 'मासिक PDF', icon: Icons.picture_as_pdf, onPressed: () => Rpt.open(context, 'jama_masik_${month}_$year', () => Reports.jamaMonthly(s, year, month)))),
            ]),
          ], 10)),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: RaisedCard(
                padding: const EdgeInsets.all(4),
                child: DataTable(
                  columnSpacing: 14,
                  headingRowHeight: 38,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 40,
                  columns: [
                    const DataColumn(label: Text('सदस्य', style: TextStyle(fontWeight: FontWeight.w800))),
                    for (final m in hiMonthsShort) DataColumn(label: Text(m, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const DataColumn(label: Text('कुल', style: TextStyle(fontWeight: FontWeight.w800))),
                  ],
                  rows: [
                    for (final m in ms)
                      DataRow(cells: [
                        DataCell(Text('${m['Full_Name']}', style: TextStyle(fontWeight: FontWeight.w700, color: p.deep))),
                        for (var mo = 1; mo <= 12; mo++)
                          DataCell(
                            Text(s.jamaAt('${m['Member_ID']}', year, mo) > 0 ? ns(s.jamaAt('${m['Member_ID']}', year, mo)) : '-'),
                            onTap: s.canWrite ? () => _editCell(m, mo) : null,
                          ),
                        DataCell(Text(ns(List.generate(12, (i) => s.jamaAt('${m['Member_ID']}', year, i + 1)).fold<num>(0, (a, b) => a + b)), style: TextStyle(fontWeight: FontWeight.w800, color: p.primary))),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------- स्टेटमेंट ----------------
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});
  @override
  State<StatementScreen> createState() => _StatementState();
}

class _StatementState extends State<StatementScreen> {
  String name = '', filter = 'सभी';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final borrowers = s.loans.map((l) => l.name).toSet().toList()..sort();
    final count = s.loans.where((l) => l.name.toLowerCase() == name.trim().toLowerCase() && (filter == 'सभी' || l.status == filter)).length;
    return AppScaffold(
      title: 'स्टेटमेंट',
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        RaisedCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
            Autocomplete<String>(
              optionsBuilder: (v) => borrowers.where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => setState(() => name = v),
              fieldViewBuilder: (c, ctrl, node, _) => AppField(
                label: 'उधारकर्ता का नाम', hint: 'नाम चुनें या लिखें...', controller: ctrl, focusNode: node, required: true,
                suffix: const Icon(Icons.arrow_drop_down), onChanged: (v) => setState(() => name = v),
              ),
            ),
            Wrap(spacing: 8, children: [
              for (final f in ['सभी', 'सक्रिय', 'पूर्ण जमा']) ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
            ]),
            Text('$count रिकॉर्ड मिले', style: TextStyle(color: context.pal.textSecondary)),
            PrimaryButton(
              label: 'Preview / Share PDF', icon: Icons.picture_as_pdf,
              onPressed: count == 0 ? null : () => Rpt.open(context, 'statement_$name', () => Reports.statement(s, name, filter)),
            ),
          ])),
        ),
      ]),
    );
  }
}

// ---------------- हर member का जमा सूची PDF ----------------
class MemberJamaScreen extends StatefulWidget {
  const MemberJamaScreen({super.key});
  @override
  State<MemberJamaScreen> createState() => _MemberJamaState();
}

class _MemberJamaState extends State<MemberJamaScreen> {
  Map<String, dynamic>? m;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return AppScaffold(
      title: 'सदस्य जमा सूची PDF',
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 30), children: [
        RaisedCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gapped([
            AppDropdown<String>(
              label: 'सदस्य का नाम', required: true, hint: 'नाम चुनें...', value: m == null ? null : '${m!['Member_ID']}',
              items: s.activeMembers.map((e) => '${e['Member_ID']}').toList(),
              labelOf: (id) => '${s.members.firstWhere((e) => '${e['Member_ID']}' == id)['Full_Name']}',
              onChanged: (v) => setState(() => m = s.members.firstWhere((e) => '${e['Member_ID']}' == v)),
            ),
            PrimaryButton(label: 'Preview / Share PDF', icon: Icons.picture_as_pdf, onPressed: m == null ? null : () => Rpt.open(context, 'member_jama', () => Reports.memberJama(s, m!))),
          ])),
        ),
      ]),
    );
  }
}
