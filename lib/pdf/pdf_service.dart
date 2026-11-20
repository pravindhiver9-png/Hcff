import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// PDFs are drawn as Flutter widgets and captured as page images, so Hindi
/// (Devanagari) text renders correctly with the app's own font.
class Rpt {
  static const bgApp = 'assets/images/app_background.png';
  static const bgStmt = 'assets/images/statement_pdf_background.png';
  static const w = 595.0, h = 842.0;
  static const green = Color(0xFF1C5238);
  static const deep = Color(0xFF133D29);
  static const mint = Color(0xFFE6EFE9);
  static const zebra = Color(0xFFF1F6F3);
  static const line = Color(0xFFC0D1C7);

  static TextStyle ts(double s, {bool b = false, Color c = const Color(0xFF1C1C1C)}) =>
      TextStyle(fontSize: s, fontWeight: b ? FontWeight.w700 : FontWeight.w500, color: c, height: 1.25);

  static Widget page(Widget child, {bool stmt = false}) {
    final inset = stmt ? const EdgeInsets.fromLTRB(34, 150, 34, 125) : const EdgeInsets.fromLTRB(34, 95, 34, 85);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: AppTheme.build(false),
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(child: Image.asset(stmt ? bgStmt : bgApp, fit: BoxFit.cover)),
              Padding(padding: inset, child: child),
            ]),
          ),
        ),
      ),
    );
  }

  static Widget header(String title, String sub) => Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
            child: const Icon(Icons.groups, color: green, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('हमारी चिट फंड फैमिली 2.0', style: ts(17, b: true, c: deep)),
              Text('विश्वास • समृद्धि • सहयोग', style: ts(9)),
            ]),
          ),
          Text(sub, style: ts(10, b: true)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(title, style: ts(12.5, b: true, c: Colors.white))),
        ),
      ]);

  static Widget smallHeader(String title, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Expanded(child: Text('हमारी चिट फंड फैमिली 2.0 - $title', style: ts(10, b: true, c: deep))),
          Text('पृष्ठ $n', style: ts(9)),
        ]),
      );

  static Widget cell(String t, int flex, {bool bold = false, Color c = const Color(0xFF1C1C1C), double size = 8.8}) =>
      Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(t, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(size, b: bold, c: c))));

  static Widget table(List<String> hd, List<List<String>> rows, List<int> flex, {List<String>? totals}) {
    Widget rowW(List<String> r, Color bg, {bool bold = false, Color c = const Color(0xFF1C1C1C), double ht = 22}) => Container(
          height: ht,
          decoration: BoxDecoration(color: bg, border: const Border(bottom: BorderSide(color: line, width: 0.6))),
          child: Row(children: [for (var i = 0; i < r.length; i++) cell(r[i], flex[i], bold: bold, c: c)]),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: line, width: 0.8)),
        child: Column(children: [
          rowW(hd, deep, bold: true, c: Colors.white, ht: 24),
          for (var i = 0; i < rows.length; i++) rowW(rows[i], i.isEven ? Colors.white : zebra),
          if (totals != null) rowW(totals, mint, bold: true),
        ]),
      ),
    );
  }

  static Widget miniCards(List<(String, String)> items, {int perRow = 3}) {
    const total = w - 68;
    final cw = (total - (perRow - 1) * 8) / perRow;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final it in items)
        Container(
          width: cw,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.85), borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.$1, style: ts(8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(it.$2, style: ts(13, b: true, c: green)),
          ]),
        ),
    ]);
  }

  /// Builds paginated report pages.
  static List<Widget> report({
    required String title,
    String sub = '',
    List<Widget> top = const [],
    required List<String> hd,
    required List<List<String>> rows,
    List<int>? flex,
    List<String>? totals,
    List<Widget> bottom = const [],
    bool stmt = false,
    int first = 16,
    int rest = 26,
  }) {
    flex ??= List.filled(hd.length, 1);
    final chunks = <List<List<String>>>[];
    var i = 0, cap = first;
    do {
      final end = min(i + cap, rows.length);
      chunks.add(rows.sublist(i, end));
      i = end;
      cap = rest;
    } while (i < rows.length);
    final hasFoot = totals != null || bottom.isNotEmpty;
    final lastCap = chunks.length == 1 ? first : rest;
    final extra = hasFoot && chunks.last.length > lastCap - 5;
    final pages = <Widget>[];
    for (var n = 0; n < chunks.length; n++) {
      final last = n == chunks.length - 1;
      final foot = last && !extra;
      pages.add(page(
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (n == 0) ...[header(title, sub), const SizedBox(height: 8), ...top, if (top.isNotEmpty) const SizedBox(height: 8)] else smallHeader(title, n + 1),
          table(hd, chunks[n], flex, totals: foot ? totals : null),
          if (foot) ...[const SizedBox(height: 10), ...bottom],
        ]),
        stmt: stmt,
      ));
    }
    if (extra) {
      pages.add(page(
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          smallHeader(title, chunks.length + 1),
          if (totals != null) table(hd, const [], flex, totals: totals),
          const SizedBox(height: 10),
          ...bottom,
        ]),
        stmt: stmt,
      ));
    }
    return pages;
  }

  static Widget signature() => Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(children: [Container(width: 120, height: 1, color: Colors.black54), const SizedBox(height: 3), Text('कोषाध्यक्ष', style: ts(9))]),
          Column(children: [Container(width: 120, height: 1, color: Colors.black54), const SizedBox(height: 3), Text('समिति के हस्ताक्षर', style: ts(9))]),
        ]),
      );

  static Widget note(String t, {bool b = false}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(t, style: ts(10.5, b: b, c: b ? deep : const Color(0xFF1C1C1C))));

  static Future<Uint8List> render(BuildContext ctx, List<Widget> pages) async {
    await precacheImage(const AssetImage(bgApp), ctx);
    await precacheImage(const AssetImage(bgStmt), ctx);
    final sc = ScreenshotController();
    final doc = pw.Document();
    for (final p in pages) {
      final img = await sc.captureFromWidget(p,
          context: ctx, pixelRatio: 3, delay: const Duration(milliseconds: 350), targetSize: const Size(w, h));
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.fill),
      ));
    }
    return doc.save();
  }

  /// Build pages -> PDF -> preview screen (with share/print).
  static Future<void> open(BuildContext ctx, String name, List<Widget> Function() build) async {
    showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final bytes = await render(ctx, build());
      if (ctx.mounted) Navigator.pop(ctx);
      if (ctx.mounted) {
        Navigator.push(ctx, MaterialPageRoute(builder: (_) => PdfPreviewScreen(bytes: bytes, name: name)));
      }
    } catch (e) {
      if (ctx.mounted) Navigator.pop(ctx);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('PDF नहीं बन सका: ${errText(e)}')));
      }
    }
  }
}

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({super.key, required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: Text(name), backgroundColor: p.primary, foregroundColor: p.onPrimary),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: '$name.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
