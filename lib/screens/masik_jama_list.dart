import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';
import '../services/finance_engine.dart';
import '../services/store.dart';
import '../ui.dart';

class MasikJamaListScreen extends StatefulWidget {
  const MasikJamaListScreen({super.key});
  @override
  State<MasikJamaListScreen> createState() => _MasikJamaListScreenState();
}

class _MasikJamaListScreenState extends State<MasikJamaListScreen> {
  final s = Store.I;

  // 0 = मासिक (Monthly), 1 = वार्षिक (Yearly)
  int _mode = 0;

  // मासिक फ़िल्टर स्टेट
  String _selectedMonthKey = FinanceEngine.monthKey(DateTime.now());
  String? _filterMemberId; // null = सभी सदस्य
  String _statusFilter = 'सभी'; // सभी | जमा | बकाया

  // वार्षिक फ़िल्टर स्टेट
  int _selectedYear = DateTime.now().year;

  static const List<String> _hindiMonths = [
    'जनवरी', 'फरवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
  ];

  List<String> get _availableMonthKeys {
    final set = <String>{FinanceEngine.monthKey(DateTime.now())};
    for (final j in s.jama) {
      if (j.month.isNotEmpty) set.add(j.month);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<int> get _availableYears {
    final set = <int>{DateTime.now().year};
    for (final j in s.jama) {
      final p = j.month.split('-');
      if (p.isNotEmpty) {
        final y = int.tryParse(p[0]);
        if (y != null) set.add(y);
      }
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  String _monthLabelHindi(String key) {
    final p = key.split('-');
    if (p.length != 2) return key;
    final y = int.tryParse(p[0]) ?? DateTime.now().year;
    final m = (int.tryParse(p[1]) ?? 1).clamp(1, 12);
    return '${_hindiMonths[m - 1]} $y';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _cleanRs(double v) =>
      v == v.roundToDouble() ? '₹${v.toInt()}' : '₹${v.toStringAsFixed(2)}';

  double _memberMonthAmount(String memberId, String monthKey) {
    double sum = 0;
    for (final j in s.jama) {
      if (j.memberId == memberId && j.month == monthKey) {
        sum += j.amount;
      }
    }
    return sum;
  }

  double _memberYearMonthAmount(String memberId, int year, int month1to12) {
    final key = '$year-${month1to12.toString().padLeft(2, '0')}';
    return _memberMonthAmount(memberId, key);
  }

  double _memberYearTotal(String memberId, int year) {
    double sum = 0;
    for (int m = 1; m <= 12; m++) {
      sum += _memberYearMonthAmount(memberId, year, m);
    }
    return sum;
  }

  List<MasikJama> _entriesForMemberMonth(String memberId, String monthKey) =>
      s.jama.where((j) => j.memberId == memberId && j.month == monthKey).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<MasikJama> _entriesForMemberYear(String memberId, int year) =>
      s.jama.where((j) => j.memberId == memberId && j.month.startsWith('$year-')).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _editEntry(MasikJama j) async {
    final amtCtrl = TextEditingController(text: j.amount.toStringAsFixed(0));
    var dDate = j.date;
    final parts = j.month.split('-');
    var mDate = parts.length == 2
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${s.memberById(j.memberId)?.name ?? 'सदस्य'} — एंट्री बदलें'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tf(amtCtrl, 'राशि (₹)', number: true),
                DateField(
                  label: 'माह (कोई भी तारीख़ चुनें)',
                  value: mDate,
                  onChanged: (d) => setLocal(() => mDate = DateTime(d.year, d.month, 1)),
                ),
                DateField(
                  label: 'जमा दिनांक',
                  value: dDate,
                  onChanged: (d) => setLocal(() => dDate = d),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('सेव')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final newAmt = num0(amtCtrl.text);
      if (newAmt > 0) j.amount = newAmt;
      j.month = FinanceEngine.monthKey(mDate);
      j.date = dDate;
      await s.save();
      if (mounted) {
        setState(() {});
        toast(context, 'मासिक जमा अपडेट हो गई');
      }
    }

    amtCtrl.dispose();
  }

  Future<void> _deleteEntry(MasikJama j) async {
    final mName = s.memberById(j.memberId)?.name ?? 'सदस्य';
    if (!await confirm(context, '$mName (${_cleanRs(j.amount)} • ${_monthLabelHindi(j.month)}) की एंट्री हटाएँ?')) {
      return;
    }
    s.jama.remove(j);
    await s.save();
    if (mounted) {
      setState(() {});
      toast(context, 'एंट्री हटा दी गई');
    }
  }

  /// किसी सदस्य की उस माह/वर्ष की एंट्रीज़ चुनकर एडिट या डिलीट करने का डायलॉग
  Future<void> _manageMemberEntriesSheet(Member m, List<MasikJama> entries, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${m.name} — $title',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: C.text),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('कोई जमा एंट्री नहीं मिली', style: TextStyle(color: C.text2)),
                )
              else
                for (final j in entries)
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_cleanRs(j.amount)}  •  ${_monthLabelHindi(j.month)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: C.text),
                              ),
                              Text(
                                'जमा दिनांक: ${_fmtDate(j.date)}',
                                style: const TextStyle(fontSize: 12, color: C.text2),
                              ),
                            ],
                          ),
                        ),
                        if (s.canEdit) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: C.accent),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _editEntry(j);
                              if (mounted) setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: C.error),
                            onPressed: () async {
                              await _deleteEntry(j);
                              entries.remove(j);
                              setModal(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- मासिक PDF जनरेटर (तीसरी इमेज के लेआउट के अनुसार, स्लेट-ब्लू थीम में) ----------------
  Future<void> _exportMonthlyPdf(List<Member> filteredMembers) async {
    const double w = 1240, h = 1754;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));

    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF2F7FC));

    final hdr = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, 1160, 175), const Radius.circular(36));
    c.drawRRect(hdr, Paint()..color = Colors.white);
    c.drawRRect(hdr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);

    void drawTxt(String txt, double x, double y, {double size = 22, Color col = C.text, bool bold = false, double? maxW, TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: txt, style: TextStyle(fontSize: size, color: col, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 2,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxW ?? double.infinity);
      tp.paint(c, Offset(x, y));
    }

    drawTxt(kGroupName, 70, 66, size: 42, bold: true);
    drawTxt('◆ विश्वास    ◆ सहयोग    ◆ समृद्धि', 70, 128, size: 24, col: C.text2);
    drawTxt('मासिक जमा रिपोर्ट\n${_monthLabelHindi(_selectedMonthKey)}', 890, 74, size: 26, bold: true, col: C.primary, maxW: 280, align: TextAlign.right);

    final banner = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 235, 1160, 80), const Radius.circular(28));
    c.drawRRect(banner, Paint()..color = C.primary);
    drawTxt('मासिक जमा विवरण — ${_monthLabelHindi(_selectedMonthKey)}', 70, 258, size: 30, bold: true, col: Colors.white);

    const double tx = 40, tw = 1160, top = 340, hh = 64, rh = 52;
    final cols = [0.09, 0.45, 0.23, 0.23].map((f) => f * tw).toList();
    final colHeads = ['क्र.', 'सदस्य का नाम', 'जमा राशि (₹)', 'स्थिति'];

    c.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTWH(tx, top, tw, hh), topLeft: const Radius.circular(20), topRight: const Radius.circular(20)),
      Paint()..color = const Color(0xFF2F5173),
    );

    double cx = tx;
    for (int i = 0; i < 4; i++) {
      drawTxt(colHeads[i], cx + 10, top + 16, size: 24, bold: true, col: Colors.white, maxW: cols[i] - 20, align: i == 0 || i == 3 ? TextAlign.center : (i == 2 ? TextAlign.right : TextAlign.left));
      cx += cols[i];
    }

    double sumAmt = 0;
    int paidCount = 0;
    for (int i = 0; i < filteredMembers.length; i++) {
      final m = filteredMembers[i];
      final amt = _memberMonthAmount(m.id, _selectedMonthKey);
      sumAmt += amt;
      final isPaid = amt >= s.monthlyAmount;
      if (isPaid) paidCount++;

      final ry = top + hh + i * rh;
      c.drawRect(
        Rect.fromLTWH(tx, ry, tw, rh),
        Paint()..color = i.isEven ? Colors.white : const Color(0xFFEAF2FA),
      );
      c.drawLine(Offset(tx, ry + rh), Offset(tx + tw, ry + rh), Paint()..color = C.border);

      double x0 = tx;
      drawTxt('${i + 1}', x0, ry + 13, size: 22, maxW: cols[0], align: TextAlign.center);
      x0 += cols[0];
      drawTxt(m.name, x0 + 14, ry + 13, size: 23, bold: true, maxW: cols[1] - 20);
      x0 += cols[1];
      drawTxt(_cleanRs(amt), x0, ry + 13, size: 23, bold: true, col: C.primary, maxW: cols[2] - 16, align: TextAlign.right);
      x0 += cols[2];
      drawTxt(isPaid ? 'जमा' : 'बकाया', x0, ry + 13, size: 22, bold: true, col: isPaid ? C.ok : C.error, maxW: cols[3], align: TextAlign.center);
    }

    final sumY = top + hh + filteredMembers.length * rh + 24;
    final sumCard = RRect.fromRectAndRadius(Rect.fromLTWH(40, sumY, 1160, 100), const Radius.circular(24));
    c.drawRRect(sumCard, Paint()..color = Colors.white);
    c.drawRRect(sumCard, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    drawTxt('कुल सदस्य: ${filteredMembers.length}', 70, sumY + 34, size: 24, bold: true);
    drawTxt('कुल जमा राशि: ${_cleanRs(sumAmt)}', 440, sumY + 34, size: 24, bold: true, col: C.primary);
    final pct = filteredMembers.isEmpty ? 0 : ((paidCount / filteredMembers.length) * 100).round();
    drawTxt('जमा स्थिति: $pct%', 880, sumY + 34, size: 24, bold: true, col: C.ok);

    drawTxt(kGroupName, 40, 1670, size: 20, col: C.text2);
    drawTxt('दिनांक: ${_fmtDate(DateTime.now())}', 980, 1670, size: 20, col: C.text2);

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    await _sharePngAsPdf(bd!.buffer.asUint8List(), 'masik_jama_$_selectedMonthKey.pdf');
  }

  // ---------------- वार्षिक PDF जनरेटर (दूसरी इमेज के लेआउट के अनुसार, स्लेट-ब्लू थीम में) ----------------
  Future<void> _exportYearlyPdf() async {
    const double w = 1240, h = 1754;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));

    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFF2F7FC));

    void drawTxt(String txt, double x, double y, {double size = 18, Color col = C.text, bool bold = false, double? maxW, TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: txt, style: TextStyle(fontSize: size, color: col, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
        ellipsis: '…',
      );
      tp.layout(maxWidth: maxW ?? double.infinity);
      tp.paint(c, Offset(x, y));
    }

    final hdr = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, 1160, 145), const Radius.circular(32));
    c.drawRRect(hdr, Paint()..color = Colors.white);
    c.drawRRect(hdr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    drawTxt(kGroupName, 70, 62, size: 38, bold: true);
    drawTxt('साथ मिलकर, आगे बढ़ें…', 70, 114, size: 22, col: C.text2);
    drawTxt('वर्ष $_selectedYear', 980, 86, size: 30, bold: true, col: C.primary);

    final subHdr = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 200, 1160, 76), const Radius.circular(24));
    c.drawRRect(subHdr, Paint()..color = C.primary);
    drawTxt('मासिक जमा की विवरणी — सभी सदस्यों की मासिक जमा राशि और कुल विवरण', 70, 222, size: 25, bold: true, col: Colors.white);

    const double tx = 40, tw = 1160, top = 295, hh = 56, rh = 46;
    // नाम (0.18) + 12 माह (12 * 0.058 = 0.696) + कुल जमा (0.124) = 1.0
    final widths = [0.18 * tw, ...List.filled(12, 0.058 * tw), 0.124 * tw];
    final xs = <double>[tx];
    for (final fw in widths) {
      xs.add(xs.last + fw);
    }

    c.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTWH(tx, top, tw, hh), topLeft: const Radius.circular(18), topRight: const Radius.circular(18)),
      Paint()..color = const Color(0xFF2F5173),
    );

    final headers = ['सदस्य का नाम', ..._hindiMonths, 'कुल जमा'];
    for (int i = 0; i < headers.length; i++) {
      drawTxt(
        headers[i],
        xs[i] + 3,
        top + 17,
        size: i == 0 || i == 13 ? 18 : 15,
        bold: true,
        col: Colors.white,
        maxW: widths[i] - 6,
        align: i == 0 ? TextAlign.left : TextAlign.center,
      );
    }

    final monthSums = List<double>.filled(12, 0);
    double grandTotal = 0;

    for (int r = 0; r < s.members.length; r++) {
      final m = s.members[r];
      final ry = top + hh + r * rh;
      c.drawRect(
        Rect.fromLTWH(tx, ry, tw, rh),
        Paint()..color = r.isEven ? Colors.white : const Color(0xFFEAF2FA),
      );
      c.drawLine(Offset(tx, ry + rh), Offset(tx + tw, ry + rh), Paint()..color = C.border);

      drawTxt(m.name, xs[0] + 8, ry + 13, size: 18, bold: true, maxW: widths[0] - 12);

      double mRowSum = 0;
      for (int mo = 1; mo <= 12; mo++) {
        final v = _memberYearMonthAmount(m.id, _selectedYear, mo);
        monthSums[mo - 1] += v;
        mRowSum += v;
        drawTxt(
          v > 0 ? _cleanRs(v) : '-',
          xs[mo],
          ry + 14,
          size: 15,
          col: v > 0 ? C.text : C.text2,
          maxW: widths[mo],
          align: TextAlign.center,
        );
      }
      grandTotal += mRowSum;
      drawTxt(_cleanRs(mRowSum), xs[13], ry + 13, size: 18, bold: true, col: C.primary, maxW: widths[13], align: TextAlign.center);
    }

    final totY = top + hh + s.members.length * rh;
    c.drawRect(Rect.fromLTWH(tx, totY, tw, rh), Paint()..color = const Color(0xFFD3E3F3));
    drawTxt('कुल योग', xs[0] + 8, totY + 13, size: 18, bold: true, maxW: widths[0] - 12);
    for (int mo = 0; mo < 12; mo++) {
      drawTxt(
        _cleanRs(monthSums[mo]),
        xs[mo + 1],
        totY + 14,
        size: 14,
        bold: true,
        maxW: widths[mo + 1],
        align: TextAlign.center,
      );
    }
    drawTxt(_cleanRs(grandTotal), xs[13], totY + 13, size: 18, bold: true, col: C.primary, maxW: widths[13], align: TextAlign.center);

    final boxY = totY + rh + 24;
    final avgMonth = monthSums.fold(0.0, (a, b) => a + b) / 12.0;
    final card = RRect.fromRectAndRadius(Rect.fromLTWH(40, boxY, 1160, 100), const Radius.circular(24));
    c.drawRRect(card, Paint()..color = Colors.white);
    c.drawRRect(card, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    drawTxt('कुल सदस्य: ${s.members.length}', 70, boxY + 34, size: 22, bold: true);
    drawTxt('मासिक औसत संग्रह: ${_cleanRs(avgMonth)}', 390, boxY + 34, size: 22, bold: true, col: C.primary);
    drawTxt('वर्ष $_selectedYear कुल जमा: ${_cleanRs(grandTotal)}', 780, boxY + 34, size: 22, bold: true, col: C.ok);

    drawTxt('समिति के हस्ताक्षर', 960, 1650, size: 22, bold: true, col: C.text2);

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    await _sharePngAsPdf(bd!.buffer.asUint8List(), 'masik_jama_$_selectedYear.pdf');
  }

  Future<void> _sharePngAsPdf(Uint8List pngBytes, String filename) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.FullPage(ignoreMargins: true, child: pw.Image(image, fit: pw.BoxFit.fill)),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final months = _availableMonthKeys;
    if (!months.contains(_selectedMonthKey) && months.isNotEmpty) {
      _selectedMonthKey = months.first;
    }

    final years = _availableYears;
    if (!years.contains(_selectedYear) && years.isNotEmpty) {
      _selectedYear = years.first;
    }

    final monthlyMembers = s.members.where((m) {
      if (_filterMemberId != null && m.id != _filterMemberId) return false;
      final amt = _memberMonthAmount(m.id, _selectedMonthKey);
      final isPaid = amt >= s.monthlyAmount;
      if (_statusFilter == 'जमा') return isPaid;
      if (_statusFilter == 'बकाया') return !isPaid;
      return true;
    }).toList();

    final monthlySum = monthlyMembers.fold<double>(
      0,
      (sum, m) => sum + _memberMonthAmount(m.id, _selectedMonthKey),
    );
    final paidCount = monthlyMembers
        .where((m) => _memberMonthAmount(m.id, _selectedMonthKey) >= s.monthlyAmount)
        .length;
    final paidPct = monthlyMembers.isEmpty ? 0 : ((paidCount / monthlyMembers.length) * 100).round();

    final yearlyGrandTotal = s.members.fold<double>(
      0,
      (sum, m) => sum + _memberYearTotal(m.id, _selectedYear),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('मासिक जमा सूची'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: _mode == 0 ? 'मासिक PDF' : 'वार्षिक PDF',
            onPressed: () => _mode == 0 ? _exportMonthlyPdf(monthlyMembers) : _exportYearlyPdf(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // मासिक / वार्षिक स्विचर + दोनों PDF बटन
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('मासिक (Monthly)'), icon: Icon(Icons.calendar_view_month)),
                    ButtonSegment<int>(value: 1, label: Text('वार्षिक (Yearly)'), icon: Icon(Icons.calendar_today)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (set) => setState(() => _mode = set.first),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportMonthlyPdf(monthlyMembers),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('मासिक PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportYearlyPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('वार्षिक PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_mode == 0) ...[
            // ---- मासिक व्यू (तीसरी इमेज के अनुसार फ़िल्टर + सूची + एडिट/डिलीट) ----
            AppCard(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedMonthKey,
                    decoration: const InputDecoration(labelText: 'माह चुनें'),
                    items: [
                      for (final mk in months)
                        DropdownMenuItem(value: mk, child: Text(_monthLabelHindi(mk))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedMonthKey = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _filterMemberId,
                          decoration: const InputDecoration(labelText: 'सदस्य'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('सभी सदस्य')),
                            for (final m in s.members)
                              DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
                          ],
                          onChanged: (v) => setState(() => _filterMemberId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(labelText: 'स्थिति'),
                          items: const [
                            DropdownMenuItem(value: 'सभी', child: Text('सभी')),
                            DropdownMenuItem(value: 'जमा', child: Text('जमा')),
                            DropdownMenuItem(value: 'बकाया', child: Text('बकाया')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _statusFilter = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            sectionTitle('मासिक जमा सूची (${_monthLabelHindi(_selectedMonthKey)})'),

            for (int i = 0; i < monthlyMembers.length; i++) ...[
              Builder(
                builder: (context) {
                  final m = monthlyMembers[i];
                  final amt = _memberMonthAmount(m.id, _selectedMonthKey);
                  final isPaid = amt >= s.monthlyAmount;
                  final mEntries = _entriesForMemberMonth(m.id, _selectedMonthKey);

                  return AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFD3E3F3),
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 13, color: C.text, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.text)),
                              Text(
                                isPaid ? 'स्थिति: जमा' : 'स्थिति: बकाया',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPaid ? C.ok : C.error),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _cleanRs(amt),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                        ),
                        if (s.canEdit && mEntries.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: C.accent),
                            onPressed: () {
                              if (mEntries.length == 1) {
                                _editEntry(mEntries.first);
                              } else {
                                _manageMemberEntriesSheet(m, mEntries, _monthLabelHindi(_selectedMonthKey));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: C.error),
                            onPressed: () {
                              if (mEntries.length == 1) {
                                _deleteEntry(mEntries.first);
                              } else {
                                _manageMemberEntriesSheet(m, mEntries, _monthLabelHindi(_selectedMonthKey));
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],

            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('कुल सदस्य: ${monthlyMembers.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                  Text('कुल जमा: ${_cleanRs(monthlySum)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.primary)),
                  Text('स्थिति: $paidPct%', style: const TextStyle(fontWeight: FontWeight.bold, color: C.ok)),
                ],
              ),
            ),
          ] else ...[
            // ---- वार्षिक व्यू (दूसरी इमेज के अनुसार वर्ष + सदस्यवार 12 माह + कुल जमा + एडिट/डिलीट) ----
            AppCard(
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'वर्ष चुनें'),
                items: [
                  for (final y in years)
                    DropdownMenuItem<int>(value: y, child: Text('वर्ष $y')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedYear = v);
                },
              ),
            ),

            sectionTitle('वार्षिक जमा विवरणी (वर्ष $_selectedYear)'),

            for (final m in s.members) ...[
              Builder(
                builder: (context) {
                  final yTotal = _memberYearTotal(m.id, _selectedYear);
                  final yEntries = _entriesForMemberYear(m.id, _selectedYear);

                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.text),
                              ),
                            ),
                            Text(
                              'कुल जमा: ${_cleanRs(yTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: C.primary),
                            ),
                            if (s.canEdit && yEntries.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: C.accent),
                                onPressed: () => _manageMemberEntriesSheet(m, yEntries, 'वर्ष $_selectedYear'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: C.error),
                                onPressed: () => _manageMemberEntriesSheet(m, yEntries, 'वर्ष $_selectedYear'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (int mo = 1; mo <= 12; mo++) ...[
                              Builder(
                                builder: (context) {
                                  final v = _memberYearMonthAmount(m.id, _selectedYear, mo);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: v > 0 ? const Color(0xFFE7F0FA) : C.bg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: v > 0 ? C.primary : C.border),
                                    ),
                                    child: Text(
                                      '${_hindiMonths[mo - 1].substring(0, 3)}: ${v > 0 ? _cleanRs(v) : '-'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: v > 0 ? FontWeight.bold : FontWeight.normal,
                                        color: v > 0 ? C.text : C.text2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('कुल सदस्य: ${s.members.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
                  Text('वर्ष $_selectedYear कुल योग: ${_cleanRs(yearlyGrandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: C.primary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
