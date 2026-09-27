import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../data/models/invoice.dart';
import '../../providers/settings_provider.dart';

class InvoicePdf {
  static Future<void> generateAndShare(Invoice inv, SettingsProvider s) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(child: pw.Text(s.storeName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          if (s.phone.isNotEmpty) pw.Center(child: pw.Text('هاتف: ${s.phone}')),
          if (s.address.isNotEmpty) pw.Center(child: pw.Text(s.address)),
          pw.Divider(),
          pw.Text('فاتورة: ${inv.number}'),
          pw.Text('الزبون: ${inv.customerName}'),
          pw.Text('التاريخ: ${inv.date.toString().substring(0, 10)}'),
          pw.Divider(),
          ...inv.items.map((it) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(it.productName)),
              pw.Text('${it.quantity} × ${it.sellPrice}'),
              pw.Text('${it.totalSell}'),
            ],
          )),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('الإجمالي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('${inv.total} ${s.currency}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('شكراً لتعاملكم معنا')),
        ],
      ),
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${inv.number}.pdf');
  }
}