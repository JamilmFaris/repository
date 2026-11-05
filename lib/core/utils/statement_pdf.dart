import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/invoice.dart';
import '../../data/models/party.dart';
import 'formatters.dart';

/// كشف حساب زبون: فواتيره ودفعاته مرتّبة زمنياً مع الرصيد المتراكم والمتبقي عليه.
class StatementPdf {
  static const _navy = PdfColor.fromInt(0xFF1E3A5F);
  static const _red = PdfColor.fromInt(0xFFB91C1C);
  static const _green = PdfColor.fromInt(0xFF15803D);
  static const _ink = PdfColor.fromInt(0xFF1F2937);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _zebra = PdfColor.fromInt(0xFFF1F5F9);

  static Future<Uint8List> build({
    required Party customer,
    required List<Invoice> invoices,
    required List<PartyPayment> payments,
    required String storeName,
    required String phone,
    required String address,
    required String currency,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final stamp = pw.MemoryImage((await rootBundle.load('assets/images/stamp.png')).buffer.asUint8List());
    final signature =
        pw.MemoryImage((await rootBundle.load('assets/images/signature.png')).buffer.asUint8List());

    // سطور الكشف: فاتورة (مدين = إجماليها، دائن = المدفوع وقت البيع) أو دفعة (دائن)
    final rows = <_Row>[
      for (final i in invoices)
        _Row(
          i.date,
          'فاتورة رقم ${i.number}',
          debit: i.total,
          credit: (i.paidAmount ?? i.total).clamp(0, i.total).toDouble(),
        ),
      for (final p in payments)
        _Row(p.date, p.note.isEmpty ? 'دفعة نقدية' : 'دفعة — ${p.note}', credit: p.amount),
    ]..sort((a, b) => a.date.compareTo(b.date));

    var running = 0.0;
    for (final r in rows) {
      running += r.debit - r.credit;
      r.balance = running;
    }
    final totalInvoices = rows.fold<double>(0, (s, r) => s + r.debit);
    final totalPaid = rows.fold<double>(0, (s, r) => s + r.credit);
    final remaining = running;

    String m(double v) => Fmt.num2(v);
    final now = DateTime.now();

    pw.Widget cell(String t,
            {bool header = false, bool right = false, PdfColor? color, bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(
            t,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: header || strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: header ? PdfColors.white : (color ?? _ink),
            ),
          ),
        );

    // الأعمدة بترتيب RTL (التاريخ أولاً من اليمين)؛ نعكس يدوياً لأن Table لا يعكس
    const flex = [2.3, 4.2, 2.2, 2.2, 2.4];
    pw.TableRow line(List<pw.Widget> c, {PdfColor? bg, bool header = false}) => pw.TableRow(
          decoration: pw.BoxDecoration(color: header ? _navy : bg),
          repeat: header,
          children: c.reversed.toList(),
        );

    final table = pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        bottom: const pw.BorderSide(color: PdfColors.grey500, width: 0.6),
      ),
      columnWidths: {
        for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[flex.length - 1 - i]),
      },
      children: [
        line([
          cell('التاريخ', header: true),
          cell('البيان', header: true, right: true),
          cell('مدين (عليه)', header: true),
          cell('دائن (دفع)', header: true),
          cell('الرصيد', header: true),
        ], header: true),
        for (var i = 0; i < rows.length; i++)
          line([
            cell(Fmt.date(rows[i].date)),
            cell(rows[i].label, right: true),
            cell(rows[i].debit == 0 ? '-' : m(rows[i].debit)),
            cell(rows[i].credit == 0 ? '-' : m(rows[i].credit), color: _green),
            cell(m(rows[i].balance), strong: true, color: rows[i].balance > 0 ? _red : _ink),
          ], bg: i.isOdd ? _zebra : PdfColors.white),
      ],
    );

    pw.Widget infoRow(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '$k ',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 11, color: _ink)),
            ]),
          ),
        );

    pw.Widget sumRow(String k, String v, {PdfColor color = _ink, bool big = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k,
                  style: pw.TextStyle(
                      fontSize: big ? 13 : 11,
                      fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text('$v $currency',
                  style: pw.TextStyle(
                      fontSize: big ? 15 : 11, fontWeight: pw.FontWeight.bold, color: color)),
            ],
          ),
        );

    pw.Widget stampBox(String? label, pw.ImageProvider image, double size) => pw.Column(children: [
          if (label != null) ...[
            pw.Text(label,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 3),
          ],
          pw.SizedBox(
            width: size * 1.5,
            height: size,
            child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        ]);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 36),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text('$storeName  •  صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _muted)),
      ),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration:
              pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(children: [
            pw.Text(storeName,
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            if (address.isNotEmpty || phone.isNotEmpty)
              pw.Text(
                  [if (address.isNotEmpty) address, if (phone.isNotEmpty) 'هاتف: $phone'].join('   •   '),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('كشف حساب',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy)),
        ),
        pw.Divider(color: _navy, thickness: 1),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              infoRow('السيد/ة:', customer.name),
              if (customer.phone.isNotEmpty) infoRow('الهاتف:', customer.phone),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              infoRow('تاريخ الكشف:', '${Fmt.date(now)}  ${Fmt.time(now)}'),
              if (rows.isNotEmpty)
                infoRow('عن المدة:', '${Fmt.date(rows.first.date)} — ${Fmt.date(rows.last.date)}'),
            ]),
          ],
        ),
        pw.SizedBox(height: 10),
        if (rows.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Center(child: pw.Text('لا توجد حركات على هذا الحساب')),
          )
        else
          table,
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _navy, width: 0.9),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: [
            sumRow('إجمالي الفواتير', m(totalInvoices)),
            sumRow('إجمالي المدفوع', m(totalPaid), color: _green),
            pw.Divider(color: PdfColors.grey400),
            sumRow('المتبقي عليه (دَين)', m(remaining < 0 ? 0 : remaining),
                color: remaining > 0 ? _red : _green, big: true),
          ]),
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [stampBox(null, stamp, 105), stampBox('التوقيع', signature, 78)],
        ),
      ],
    ));
    return doc.save();
  }

  static Future<void> share(Uint8List bytes, String customerName) =>
      Printing.sharePdf(bytes: bytes, filename: 'كشف-حساب-$customerName.pdf');
}

class _Row {
  final DateTime date;
  final String label;
  final double debit;
  final double credit;
  double balance = 0;
  _Row(this.date, this.label, {this.debit = 0, this.credit = 0});
}
