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
  static const int perPage = 23;
  static const double tableX = 40, tableW = 1160, tableTop = 350, headH = 78, rowH = 46;
  static const List<double> frac = [0.05, 0.17, 0.09, 0.10, 0.06, 0.09, 0.09, 0.09, 0.10, 0.08, 0.08];
  static const List<String> heads = [
    'क्र.', 'नाम', 'मूलधन', 'दिनांक', 'ब्याज\nदर', 'ब्याज\nजमा',
    'मूलधन\nजमा', 'कुल\nजमा', 'जमा\nदिनांक', 'स्थिति', 'नोट'
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

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _rate(double r) =>
      '${r == r.roundToDouble() ? r.toInt().toString() : r.toString()}%';

  static Future<Uint8List> _page(
    int pi,
    int pc,
    List<_Row> rows,
    int startIdx,
    String filter,
    ui.Image? bg,
    ui.Image? logo,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, W, H));
    c.drawRect(const Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFFF2F7FC));
    if (bg != null) {
      c.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        const Rect.fromLTWH(0, 0, W, H),
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    // ---- हेडर कार्ड ----
    final hdr = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, 1160, 190), const Radius.circular(44));
    c.drawRRect(hdr.shift(const Offset(0, 6)), Paint()..color = const Color(0x2A1E324B)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    c.drawRRect(hdr, Paint()..color = const Color(0xEBFFFFFF));
    c.drawRRect(hdr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);

    const lc = Offset(150, 135);
    c.drawCircle(lc, 84, Paint()..color = Colors.white);
    c.drawCircle(lc, 84, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = C.border);
    if (logo != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: lc, radius: 76)));
      c.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromCircle(center: lc, radius: 76),
        Paint()..filterQuality = FilterQuality.high,
      );
      c.restore();
    } else {
      _text(c, 'HCFF', lc.dx - 60, lc.dy - 18, size: 34, bold: true, color: C.primary, w: 120, align: TextAlign.center);
    }
    c.drawLine(const Offset(262, 78), const Offset(262, 192), Paint()..color = C.border..strokeWidth = 3);
    _text(c, kGroupName, 290, 66, size: 48, bold: true);
    _text(c, '◆ विश्वास    ◆ सहयोग    ◆ समृद्धि', 290, 140, size: 27, color: C.text2);

    final chip = RRect.fromRectAndRadius(const Rect.fromLTWH(1040, 98, 140, 72), const Radius.circular(36));
    c.drawRRect(chip, Paint()..color = C.primary);
    _text(c, filter, 1040, 98, size: 30, bold: true, color: Colors.white, w: 140, align: TextAlign.center, boxH: 72);

    // ---- शीर्षक पट्टी ----
    final pill = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 258, 1160, 66), const Radius.circular(33));
    c.drawRRect(pill, Paint()..color = const Color(0xDDD3E3F3));
    c.drawRRect(pill, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.border);
    _text(c, 'मासिक ऋण एवं वित्तीय लेन-देन विवरण  •  ${_d(DateTime.now())}', 40, 258, size: 27, bold: true, w: 1160, align: TextAlign.center, boxH: 66);

    // ---- टेबल हेडर ----
    final widths = [for (final f in frac) f * tableW];
    final xs = <double>[tableX];
    for (final w in widths) {
      xs.add(xs.last + w);
    }
    final headRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(tableX, tableTop, tableW, headH),
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
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
      _text(c, heads[i], xs[i], tableTop, size: 21, bold: true, color: Colors.white, w: widths[i], align: TextAlign.center, maxLines: 2, boxH: headH);
      if (i > 0) {
        c.drawLine(Offset(xs[i], tableTop + 14), Offset(xs[i], tableTop + headH - 14), Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.5);
      }
    }

    // ---- पंक्तियाँ (Zebra striping केवल डेटा/कुल पंक्तियों पर) ----
    final y0 = tableTop + headH;
    int dataIndex = 0;
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final y = y0 + r * rowH;

      if (!row.empty) {
        final fill = row.total
            ? const Color(0xF2C9DBEE)
            : (dataIndex.isEven ? const Color(0xEBFFFFFF) : const Color(0xEBEAF2FA));
        c.drawRect(Rect.fromLTWH(tableX, y, tableW, rowH), Paint()..color = fill);
        dataIndex++;
      }

      c.drawLine(Offset(tableX, y + rowH), Offset(tableX + tableW, y + rowH), Paint()..color = C.border..strokeWidth = 1);

      for (var i = 0; i < 11; i++) {
        if (i > 0) {
          c.drawLine(Offset(xs[i], y), Offset(xs[i], y + rowH), Paint()..color = const Color(0x66B8CBE0)..strokeWidth = 1);
        }
        if (row.empty) continue;

        final v = row.cells[i];
        final x = xs[i];
        final w = widths[i];
        if (i == 0) {
          if (!row.total) {
            c.drawCircle(Offset(x + w / 2, y + rowH / 2), 19, Paint()..color = const Color(0xFFD3E3F3));
            _text(c, '${startIdx + r + 1}', x, y, size: 20, w: w, align: TextAlign.center, boxH: rowH);
          }
        } else if (i == 1) {
          _text(c, v, x + 12, y, size: 22, bold: row.total, w: w - 16, boxH: rowH);
        } else if (i == 2 || i == 5 || i == 6 || i == 7) {
          _text(c, v, x, y, size: 21, bold: row.total, w: w - 12, align: TextAlign.right, boxH: rowH);
        } else if (i == 9) {
          _text(c, v, x, y, size: 20, bold: row.active, color: row.active ? C.accent : const Color(0xFF2F5173), w: w, align: TextAlign.center, boxH: rowH);
        } else if (i == 10) {
          _text(c, v, x + 4, y, size: 15, w: w - 8, maxLines: 2, align: TextAlign.center, boxH: rowH);
        } else {
          _text(c, v, x, y, size: 21, bold: row.total, w: w, align: TextAlign.center, boxH: rowH);
        }
      }
    }

    final tableH = headH + rows.length * rowH;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tableX, tableTop, tableW, tableH), const Radius.circular(24)),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = C.accent,
    );

    // बॉटम पेज लेबल: बाएँ ग्रुप नाम, दाएँ पेज नंबर
    _text(c, kGroupName, tableX, tableTop + tableH + 8, size: 18, color: C.text2, w: tableW / 2, align: TextAlign.left);
    _text(c, 'पेज $pi / $pc', tableX + tableW / 2, tableTop + tableH + 8, size: 18, color: C.text2, w: tableW / 2, align: TextAlign.right);

    // ---- मुख्य फ़ुटर केवल अंतिम पेज पर ----
    if (pi == pc) {
      _text(c, kTagline, 70, 1640, size: 36, bold: true, italic: true, color: Colors.white, w: 480);
      _text(c, kGroupName, 780, 1655, size: 24, color: const Color(0xDDFFFFFF), w: 390, align: TextAlign.right);
    }

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

    final pages = <List<_Row>>[];
    for (var i = 0; i < rows.length; i += perPage) {
      pages.add(rows.sublist(i, i + perPage > rows.length ? rows.length : i + perPage));
    }

    final doc = pw.Document();
    for (var p = 0; p < pages.length; p++) {
      final png = await _page(p + 1, pages.length, pages[p], p * perPage, filterLabel, bg, logo);
      final image = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.FullPage(ignoreMargins: true, child: pw.Image(image, fit: pw.BoxFit.fill)),
        ),
      );
    }
    await Printing.sharePdf(bytes: await doc.save(), filename: 'udhar_list.pdf');
    return bg == null ? 'बैकग्राउंड इमेज नहीं मिली: assets/images/pdf_bg.png जाँचें' : null;
  }
}
