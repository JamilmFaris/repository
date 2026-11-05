import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/receipt.dart';
import 'arabic_words.dart';
import 'formatters.dart';

class ReceiptPdf {
  static Future<Uint8List> build({
    required Receipt receipt,
    required String storeName,
    required String phone,
    required String currency,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final base = pw.TextStyle(font: regular, fontSize: 13);
    final strong = pw.TextStyle(font: bold, fontSize: 13, fontWeight: pw.FontWeight.bold);
    final green = PdfColor.fromInt(0xFF2E7D5B);
    final currencyName = currency == 'ل.س' ? 'ليرة سورية' : currency;

    final stamp = pw.MemoryImage((await rootBundle.load('assets/images/stamp.png')).buffer.asUint8List());
    final signature =
        pw.MemoryImage((await rootBundle.load('assets/images/signature.png')).buffer.asUint8List());

    // العنوان والنص في فقرة واحدة فيقعان على نفس خط الأساس (بدل Row بخطّين مختلفين)
    pw.Widget line(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$k ', style: strong),
              pw.TextSpan(text: v, style: base),
            ]),
          ),
        );

    pw.Widget stampBox(String? label, pw.ImageProvider image, double height) => pw.Expanded(
          child: pw.Column(
            children: [
              if (label != null) ...[
                pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 11, color: green)),
                pw.SizedBox(height: 3),
              ],
              pw.SizedBox(
                height: height,
                child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
              ),
            ],
          ),
        );

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: green, width: 1.2),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(storeName,
                  style: pw.TextStyle(font: bold, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            if (phone.isNotEmpty) pw.Center(child: pw.Text('هاتف: $phone', style: base)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text('وصل استلام مبلغ',
                  style: pw.TextStyle(font: bold, fontSize: 16, color: green)),
            ),
            pw.Divider(color: green),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('رقم الوصل: ${receipt.number}', style: strong),
                pw.Text('التاريخ: ${Fmt.date(receipt.date)}  ${Fmt.time(receipt.date)}', style: base),
              ],
            ),
            pw.SizedBox(height: 8),
            line('استلمتُ من السيد:', receipt.customerName),
            line('مبلغاً وقدره:',
                '${Fmt.num2(receipt.amount)} $currency — ${ArabicWords.money(receipt.amount, currencyName: currencyName)}'),
            if (receipt.purpose.isNotEmpty) line('وذلك مقابل:', receipt.purpose),
            if (receipt.note.isNotEmpty) line('ملاحظة:', receipt.note),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                stampBox(null, stamp, 110),
                pw.SizedBox(width: 14),
                stampBox('التوقيع', signature, 78),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text('شكراً لتعاملكم معنا', style: pw.TextStyle(font: bold, color: green)),
            ),
          ],
        ),
      ),
    ));
    return doc.save();
  }
}
