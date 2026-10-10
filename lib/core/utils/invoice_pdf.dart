import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/invoice.dart';
import '../../providers/settings_provider.dart';
import 'formatters.dart';
import 'invoice_text.dart';

/// فاتورة PDF بمقاس A6 (بحجم كف اليد) بخط عربي مُضمَّن ويعمل بدون إنترنت.
class InvoicePdf {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<Uint8List> build(Invoice inv, SettingsProvider s) async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final regular = _regular!, bold = _bold!;

    final doc = pw.Document();
    final base = pw.TextStyle(font: regular, fontSize: 9);
    final strong = pw.TextStyle(font: bold, fontSize: 9, fontWeight: pw.FontWeight.bold);
    const border = PdfColors.grey600;

    // ترتيب الأعمدة (من اليمين): القيمة الإجمالية | البيان | العدد | السعر
    pw.Widget cell(String text, {int flex = 1, bool header = false, pw.TextAlign? align}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: border, width: 0.5),
              color: header ? PdfColors.grey300 : null,
            ),
            child: pw.Text(text,
                style: header ? strong : base,
                textAlign: align ?? pw.TextAlign.center),
          ),
        );

    pw.Widget row(String total, String name, String qty, String price, {bool header = false}) =>
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            cell(total, flex: 3, header: header),
            cell(name, flex: 5, header: header, align: pw.TextAlign.right),
            cell(qty, flex: 2, header: header),
            cell(price, flex: 3, header: header),
          ],
        );

    final totalSell = inv.total;

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(14),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      build: (ctx) => [
        pw.Center(child: pw.Text(s.storeName, style: pw.TextStyle(font: bold, fontSize: 15, fontWeight: pw.FontWeight.bold))),
        if (s.phone.isNotEmpty)
          pw.Center(child: pw.Text('هاتف: ${s.phone}', style: base, textDirection: pw.TextDirection.rtl)),
        if (s.address.isNotEmpty) pw.Center(child: pw.Text(s.address, style: base)),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('رقم الفاتورة: ${inv.number}', style: strong),
            pw.Text('${Fmt.date(inv.date)}  ${Fmt.time(inv.date)}', style: base),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text('الصيدلاني/ة المحترم/ة: ${inv.customerName}', style: strong),
        pw.SizedBox(height: 6),
        row('القيمة الإجمالية', 'البيان', 'العدد', 'السعر', header: true),
        ...inv.items.map((it) {
          final note = invoiceItemNote(it, s.currency);
          return row(
            Fmt.num2(it.totalSell),
            note == null ? invoiceItemName(it) : '${invoiceItemName(it)}\n$note',
            '${it.quantity}',
            Fmt.num2(it.sellPrice),
          );
        }),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border, width: 0.5),
            color: PdfColors.grey200,
          ),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(
            children: [
              if (inv.totalDiscount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المجموع الكلي قبل الخصم', style: base),
                    pw.Text('${Fmt.num2(inv.grossTotal)} ${s.currency}', style: base),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'الخصم${inv.discountType == 'percent' ? ' (فاتورة ${Fmt.num2(inv.discountValue)}%)' : ''}'
                        '${inv.couponCode != null ? ' - كوبون ${inv.couponCode}' : ''}',
                        style: base),
                    pw.Text('- ${Fmt.num2(inv.totalDiscount)} ${s.currency}', style: base),
                  ],
                ),
                pw.Divider(height: 6, thickness: 0.5, color: border),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(inv.totalDiscount > 0 ? 'المجموع الكلي بعد الخصم' : 'المجموع', style: strong),
                  pw.Text('${Fmt.num2(totalSell)} ${s.currency}', style: strong),
                ],
              ),
            ],
          ),
        ),
        if (inv.notes.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('ملاحظة: ${inv.notes}', style: base),
        ],
      ],
    ));

    return doc.save();
  }

  static Future<void> generateAndShare(Invoice inv, SettingsProvider s) async {
    final bytes = await build(inv, s);
    await Printing.sharePdf(bytes: bytes, filename: 'فاتورة-${inv.number}.pdf');
  }
}
