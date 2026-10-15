import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'formatters.dart';
import 'report_data.dart';

class MovementPdf {
  static Future<Uint8List> build({
    required List<MovementRow> rows,
    required DateTime from,
    required DateTime to,
    required String storeName,
    required String currency,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final base = pw.TextStyle(font: regular, fontSize: 9);
    final head = pw.TextStyle(font: bold, fontSize: 9, fontWeight: pw.FontWeight.bold);

    // جدول حقيقي: الأعمدة بترتيب RTL (الصنف أولاً من اليمين) وارتفاع موحَّد للصف
    const flex = [4.0, 2.0, 2.0, 2.0, 2.0, 3.0, 3.0];
    pw.TableRow line(List<String> v, {bool header = false}) => pw.TableRow(
          decoration: header ? const pw.BoxDecoration(color: PdfColors.grey300) : null,
          children: [
            // Table لا يعكس الاتجاه تلقائياً، فنعكس الأعمدة يدوياً لتبدأ من اليمين
            for (var i = v.length - 1; i >= 0; i--)
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  v[i],
                  style: header ? head : base,
                  textAlign: i == 0 ? pw.TextAlign.right : pw.TextAlign.center,
                ),
              ),
          ],
        );

    final totalQty = rows.fold<int>(0, (s, r) => s + r.qty);
    final totalMine = rows.fold<int>(0, (s, r) => s + r.giftsMine);
    final totalCo = rows.fold<int>(0, (s, r) => s + r.giftsCompany);
    final totalRev = rows.fold<double>(0, (s, r) => s + r.revenue);
    final totalProfit = rows.fold<double>(0, (s, r) => s + r.profit);
    final invoiceIds = <int>{for (final r in rows) ...r.invoiceIds};

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      build: (ctx) => [
        pw.Center(child: pw.Text(storeName, style: pw.TextStyle(font: bold, fontSize: 16))),
        pw.Center(
          child: pw.Text('حركة الأصناف من ${Fmt.date(from)} إلى ${Fmt.date(to)}', style: base),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: {
            for (var i = 0; i < flex.length; i++)
              i: pw.FlexColumnWidth(flex[flex.length - 1 - i]),
          },
          children: [
            line(['الصنف', 'المباع', 'هدايا حسابي', 'هدايا الشركة', 'الفواتير', 'الإيراد ($currency)', 'الربح الصافي ($currency)'],
                header: true),
            for (final r in rows)
              line([
                r.name,
                '${r.qty}',
                '${r.giftsMine}',
                '${r.giftsCompany}',
                '${r.invoiceIds.length}',
                Fmt.num2(r.revenue),
                Fmt.num2(r.profit),
              ]),
            line([
              'الإجمالي',
              '$totalQty',
              '$totalMine',
              '$totalCo',
              '${invoiceIds.length}',
              Fmt.num2(totalRev),
              Fmt.num2(totalProfit),
            ], header: true),
          ],
        ),
      ],
    ));
    return doc.save();
  }

  static Future<void> share({
    required List<MovementRow> rows,
    required DateTime from,
    required DateTime to,
    required String storeName,
    required String currency,
  }) async {
    final bytes = await build(
        rows: rows, from: from, to: to, storeName: storeName, currency: currency);
    await Printing.sharePdf(bytes: bytes, filename: 'movement-report.pdf');
  }
}
