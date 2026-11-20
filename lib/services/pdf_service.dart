import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';
import '../ui.dart';

class PdfService {
  static Future<pw.MemoryImage?> _img(String path) async {
    try {
      return pw.MemoryImage((await rootBundle.load(path)).buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// उधार लिस्ट की PDF बनाकर शेयर (WhatsApp आदि) करता है। पहली बार फ़ॉन्ट के लिए नेट चाहिए।
  static Future<void> shareLoans(List<Loan> loans, String filterLabel) async {
    final font = await PdfGoogleFonts.notoSansDevanagariRegular();
    final bold = await PdfGoogleFonts.notoSansDevanagariBold();
    final bg = await _img('assets/images/pdf_bg.png');
    final logo = await _img('assets/images/logo.png');
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

    final headers = ['क्र.', 'नाम', 'मूलधन', 'दिनांक', 'दर %', 'ब्याज जमा', 'मूलधन जमा', 'कुल जमा', 'जमा दिनांक', 'स्थिति', 'नोट'];
    final rows = <List<String>>[];
    for (var i = 0; i < loans.length; i++) {
      final l = loans[i];
      rows.add([
        '${i + 1}', l.borrower, rs(l.principal), dt(l.date), l.rate.toString(), rs(l.interestPaid), rs(l.principalPaid),
        rs(l.interestPaid + l.principalPaid), l.repayDate == null ? '-' : dt(l.repayDate!), l.status, l.note,
      ]);
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        buildBackground: bg == null
            ? null
            : (ctx) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Stack(fit: pw.StackFit.expand, children: [
                    pw.Image(bg, fit: pw.BoxFit.cover),
                    pw.Opacity(opacity: 0.88, child: pw.Container(color: PdfColors.white)),
                  ]),
                ),
      ),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(children: [
          if (logo != null) pw.Image(logo, height: 40, width: 40),
          pw.SizedBox(width: 10),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(kGroupName, style: pw.TextStyle(font: bold, fontSize: 16)),
            pw.Text('उधार लिस्ट — $filterLabel • ${dt(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
          ]),
        ]),
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#476B91')),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColor.fromHex('#C3D4E6')),
        ),
      ],
    ));
    await Printing.sharePdf(bytes: await doc.save(), filename: 'udhar_list.pdf');
  }
}
