import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';
import '../ui.dart';

class _Row {
  final List<String> cells;
  final bool total;
  final bool active;
  final bool empty;
  _Row(this.cells, {this.total = false, this.active = false, this.empty = false});
}

/// हर पेज Flutter के कैनवास पर बनता है (हिंदी मात्राएँ सही आती हैं, नेट/फ़ॉन्ट डाउनलोड नहीं चाहिए),
/// फिर PNG बनाकर PDF पेज में लगाया जाता है।
class PdfService {
  static const double W = 1240, H = 1754; // A4 @150dpi
  static const int perPageNormal = 27; // सामान्य पेजों पर अधिक पंक्तियाँ
  static const int perPageLast = 24;   // अंतिम पेज पर मुख्य फुटर के लिए जगह छोड़कर पंक्तियाँ
  static const double tableX = 40, tableW = 1160, tableTop = 342, headH = 76, rowH = 44;
  static const List<double> frac = [0.05, 0.17, 0.09, 0.10, 0.06, 0.09, 0.09, 0.09, 0.10, 0.08, 0.08];
  static const List<String> heads = [
    'क्र.', 'नाम', 'मूलधन', 'दिनांक', 'ब्याज\nदर',
    'ब्याज\nजमा', 'मूलधन\nजमा', 'कुल\nजमा', 'जमा\nदिनांक', 'स्थिति', 'नोट'
  ];

  static Future<ui.Image?> _load(List<String> paths) async {
    for (final p in paths) {
      try {
        final d = await rootBundle.load(p);
        final codec = await ui.instantiateImageCodec(d.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      } catch (_) {}
    }
    return null;
  }

  static void _text(
    Canvas c,
    String s,
    double x,
    double y, {
    double size = 20,
    Color color = C.text,
    bool bold = false,
    double? w,
    TextAlign align = TextAlign.left,
    int maxLines = 1,
    double? boxH,
    bool italic = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    );
    tp.layout(minWidth: w ?? 0, maxWidth: w ?? double.infinity);
    final dy = boxH == null ? 0.0 : (boxH - tp.height) / 2;
    tp.paint(c, Offset(x, y + dy));
  }

  static void _drawFooterIcon(Canvas c, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _rate(double r) =>
      '${r == r.roundToDouble() ? r.toInt().toString() : r.toString()}%';

  static Future<Uint8List> _page(
    int pi,
    int pc,
    List<_Row> rawRows,
    int startIdx,
    String filter,
    ui.Image? bg,
    ui.Image? logo,
  ) async {
    final isLastPage = (pi == pc);
    final targetSlots = isLastPage ? perPageLast : perPageNormal;

    // कम प्रविष्टियाँ होने पर पेज को खाली दिखने से बचाने के लिए ग्रिड पंक्तियाँ भरें
    final rows = List<_Row>.from(rawRows);
    while (rows.length < targetSlots) {
      rows.add(_Row(List.filled(11, ''), empty: true));
    }

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));

    // पेज बैकग्राउंड (आपका वही Slate-Blue / Ice Mist रंग)
    c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFFF2F7FC));
    if (bg != null) {
      c.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        const Rect.fromLTWH(0, 0, W, H),
        Paint()..filterQuality = FilterQuality.high,
      );
      // ताकि बैकग्राउंड वेव/इमेज के ऊपर ग्रिड और फुटर साफ दिखे
      c.drawRect(
        const Rect.fromLTWH(0, 330, W, H - 330),
        Paint()..color = const Color(0xDCFFFFFF),
      );
    }

    // ---- 1. हेडर कार्ड (2nd Image लेआउट, आपका Slate-Blue रंग) ----
    final hdr = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 36, 1160, 186), const Radius.circular(42));
    c.drawRRect(
      hdr.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x261E324B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    c.drawRRect(hdr, Paint()..color = const Color(0xF5FFFFFF));
    c.drawRRect(hdr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);

    const lc = Offset(148, 129);
    c.drawCircle(lc, 80, Paint()..color = const Color(0xFFEAF2FA));
    c.drawCircle(lc, 80, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = C.border);
    if (logo != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: lc, radius: 74)));
      c.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromCircle(center: lc, radius: 74),
        Paint()..filterQuality = FilterQuality.high,
      );
      c.restore();
    } else {
      _text(c, 'HCFF', lc.dx - 60, lc.dy - 18, size: 34, bold: true, color: C.primary, w: 120, align: TextAlign.center);
    }

    c.drawLine(const Offset(256, 72), const Offset(256, 186), Paint()..color = C.border..strokeWidth = 3);
    _text(c, kGroupName, 282, 60, size: 46, bold: true, color: C.text);
    _text(c, '◆ विश्वास   ◆ सहयोग   ◆ समृद्धि   ◆ स्थापना: फरवरी 2025', 282, 134, size: 24, color: C.text2);

    final chip = RRect.fromRectAndRadius(const Rect.fromLTWH(1036, 94, 144, 70), const Radius.circular(35));
    c.drawRRect(chip, Paint()..color = C.primary);
    _text(c, filter, 1036, 94, size: 28, bold: true, color: Colors.white, w: 144, align: TextAlign.center, boxH: 70);

    // ---- 2. शीर्षक पट्टी (2nd Image जैसा पूरा शीर्षक) ----
    final pill = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 248, 1160, 68), const Radius.circular(24));
    c.drawRRect(pill, Paint()..color = const Color(0xFFE1ECF7));
    c.drawRRect(pill, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    _text(
      c,
      'मासिक ऋण एवं वित्तीय लेन-देन प्रबंधन प्रणाली (सक्रिय सदस्य एवं बाहरी विवरण)',
      40,
      248,
      size: 25,
      bold: true,
      color: C.text,
      w: 1160,
      align: TextAlign.center,
      boxH: 68,
    );

    // ---- 3. टेबल हेडर ----
    final widths = [for (final f in frac) f * tableW];
    final xs = <double>[tableX];
    for (final w in widths) {
      xs.add(xs.last + w);
    }
    final headRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(tableX, tableTop, tableW, headH),
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
    );
    c.drawRRect(
      headRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, tableTop),
          const Offset(0, tableTop + headH),
          [const Color(0xFF4F76A0), const Color(0xFF2F5173)],
        ),
    );
    for (var i = 0; i < heads.length; i++) {
      _text(c, heads[i], xs[i], tableTop, size: 20, bold: true, color: Colors.white, w: widths[i], align: TextAlign.center, maxLines: 2, boxH: headH);
      if (i > 0) {
        c.drawLine(
          Offset(xs[i], tableTop),
          Offset(xs[i], tableTop + headH),
          Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.2,
        );
      }
    }

    // ---- 4. पंक्तियाँ (केवल डेटा/कुल पंक्तियों में ज़ेबरा रंग, खाली पंक्तियाँ साफ़) ----
    final y0 = tableTop + headH;
    final tableH = headH + rows.length * rowH;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final y = y0 + r * rowH;
      final fill = row.empty
          ? const Color(0xFFFFFFFF)
          : (row.total
              ? const Color(0xFFD5E4F4)
              : (r.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFF3F8FD)));

      if (r == rows.length - 1) {
        final bottomRowRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(tableX, y, tableW, rowH),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        );
        c.drawRRect(bottomRowRect, Paint()..color = fill);
      } else {
        c.drawRect(Rect.fromLTWH(tableX, y, tableW, rowH), Paint()..color = fill);
        c.drawLine(
          Offset(tableX, y + rowH),
          Offset(tableX + tableW, y + rowH),
          Paint()..color = C.border..strokeWidth = 1.0,
        );
      }

      if (row.empty) continue;

      for (var i = 0; i < 11; i++) {
        final v = row.cells[i];
        final x = xs[i];
        final w = widths[i];
        if (i == 0) {
          if (!row.total) {
            c.drawCircle(Offset(x + w / 2, y + rowH / 2), 17, Paint()..color = const Color(0xFFD8E6F5));
            _text(c, '${startIdx + r + 1}', x, y, size: 19, bold: true, color: C.text, w: w, align: TextAlign.center, boxH: rowH);
          }
        } else if (i == 1) {
          _text(c, v, x + 12, y, size: 21, bold: row.total, color: C.text, w: w - 16, boxH: rowH);
        } else if (i == 2 || i == 5 || i == 6 || i == 7) {
          _text(c, v, x, y, size: 20, bold: row.total, color: C.text, w: w - 12, align: TextAlign.right, boxH: rowH);
        } else if (i == 9) {
          _text(
            c,
            v,
            x,
            y,
            size: 19,
            bold: row.active,
            color: row.active ? C.accent : const Color(0xFF2F5173),
            w: w,
            align: TextAlign.center,
            boxH: rowH,
          );
        } else if (i == 10) {
          _text(c, v, x + 4, y, size: 14, color: C.text2, w: w - 8, maxLines: 2, align: TextAlign.center, boxH: rowH);
        } else {
          _text(c, v, x, y, size: 20, bold: row.total, color: C.text, w: w, align: TextAlign.center, boxH: rowH);
        }
      }
    }

    // कॉलम की वर्टिकल ग्रिड लाइन्स (पूरी टेबल में ऊपर से नीचे तक)
    for (var i = 1; i < 11; i++) {
      c.drawLine(
        Offset(xs[i], y0),
        Offset(xs[i], tableTop + tableH),
        Paint()..color = C.border..strokeWidth = 1.0,
      );
    }

    // बाहरी टेबल बॉर्डर
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tableX, tableTop, tableW, tableH), const Radius.circular(20)),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..color = C.primary,
    );

    // ---- 5. मुख्य 3-आइकन फुटर (केवल अंतिम पेज पर) ----
    if (isLastPage) {
      const footerTop = 1502.0;
      const footerH = 176.0;
      final footerBox = RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, footerTop, 1160, footerH),
        const Radius.circular(24),
      );
      c.drawRRect(footerBox, Paint()..color = const Color(0xFFE7F0FA));
      c.drawRRect(footerBox, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = C.border);

      // बाईं ओर टैगलाइन
      _text(
        c,
        kTagline,
        64,
        footerTop,
        size: 36,
        bold: true,
        italic: true,
        color: C.primary,
        w: 490,
        align: TextAlign.center,
        boxH: footerH,
      );

      // बीच की वर्टिकल विभाजन रेखा
      c.drawLine(
        const Offset(575, footerTop + 26),
        const Offset(575, footerTop + footerH - 26),
        Paint()..color = C.border..strokeWidth = 2.5,
      );

      // दाईं ओर 3 आइकन ब्लॉक
      final items = [
        (Icons.groups_rounded, 'समूह की शक्ति', 680.0),
        (Icons.handshake_rounded, 'सहयोग हमारा बल', 885.0),
        (Icons.trending_up_rounded, 'समृद्धि हमारा लक्ष्य', 1090.0),
      ];

      for (final item in items) {
        final iconData = item.$1;
        final label = item.$2;
        final cx = item.$3;

        final iconBox = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, footerTop + 66), width: 88, height: 76),
          const Radius.circular(18),
        );
        c.drawRRect(iconBox, Paint()..color = Colors.white);
        c.drawRRect(iconBox, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = C.border);
        _drawFooterIcon(c, iconData, Offset(cx, footerTop + 66), 46, C.primary);

        _text(
          c,
          label,
          cx - 95,
          footerTop + 114,
          size: 19,
          bold: true,
          color: C.text,
          w: 190,
          align: TextAlign.center,
        );
      }
    }

    // ---- 6. हर पेज के बिल्कुल नीचे बाएँ समूह का नाम और दाएँ पेज नंबर ----
    _text(c, kGroupName, 44, 1700, size: 20, bold: true, color: C.text2, w: 600, align: TextAlign.left);
    _text(c, 'पेज $pi / $pc', 640, 1700, size: 20, bold: true, color: C.text2, w: 556, align: TextAlign.right);

    final img = await rec.endRecording().toImage(W.toInt(), H.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  /// उधार लिस्ट की PDF बनाकर शेयर करता है। वापसी: चेतावनी (अगर बैकग्राउंड इमेज न मिली), वरना null
  static Future<String?> shareLoans(List<Loan> loans, String filterLabel) async {
    final bg = await _load(['assets/images/pdf_bg.png', 'assets/images/pdf_bg.jpg', 'assets/images/pdf_bg.jpeg']);
    final logo = await _load(['assets/images/logo.png', 'assets/images/logo.jpg']);

    final rows = <_Row>[];
    double tp = 0, ti = 0, tpp = 0;
    for (final l in loans) {
      final paid = l.interestPaid > 0 || l.principalPaid > 0 || l.repayDate != null;
      tp += l.principal;
      ti += l.interestPaid;
      tpp += l.principalPaid;
      rows.add(_Row([
        '',
        l.borrower,
        rs(l.principal),
        _d(l.date),
        _rate(l.rate),
        paid ? rs(l.interestPaid) : '',
        paid ? rs(l.principalPaid) : '',
        paid ? rs(l.interestPaid + l.principalPaid) : '',
        l.repayDate == null ? '' : _d(l.repayDate!),
        l.status,
        l.note,
      ], active: l.active));
    }
    rows.add(_Row(['', 'कुल', rs(tp), '', '', rs(ti), rs(tpp), rs(ti + tpp), '', '', ''], total: true));

    // पेजों का बँटवारा: आखिरी पेज पर मुख्य फुटर के लिए perPageLast पंक्तियाँ
    final pages = <List<_Row>>[];
    final startIndices = <int>[];
    var idx = 0;
    while (idx < rows.length) {
      final remaining = rows.length - idx;
      if (remaining <= perPageLast) {
        startIndices.add(idx);
        pages.add(rows.sublist(idx));
        break;
      } else if (remaining <= perPageNormal) {
        startIndices.add(idx);
        pages.add(rows.sublist(idx, idx + perPageLast));
        idx += perPageLast;
      } else {
        startIndices.add(idx);
        pages.add(rows.sublist(idx, idx + perPageNormal));
        idx += perPageNormal;
      }
    }

    final doc = pw.Document();
    for (var p = 0; p < pages.length; p++) {
      final png = await _page(p + 1, pages.length, pages[p], startIndices[p], filterLabel, bg, logo);
      final image = pw.MemoryImage(png);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.FullPage(ignoreMargins: true, child: pw.Image(image, fit: pw.BoxFit.fill)),
      ));
    }
    await Printing.sharePdf(bytes: await doc.save(), filename: 'udhar_list.pdf');
    return bg == null ? 'बैकग्राउंड इमेज नहीं मिली: assets/images/pdf_bg.png जाँचें' : null;
  }
}
