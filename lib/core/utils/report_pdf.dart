import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'capital.dart';
import 'formatters.dart';
import 'report_data.dart';

class ReportPdf {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<Uint8List> build({
    required ReportData data,
    required CapitalSummary capital,
    required String storeName,
    required String currency,
    double capitalRate = 0, // سعر الدولار لتحويل رأس المال
    double profitRate = 0, // سعر الدولار لتحويل الربح
  }) async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final base = pw.TextStyle(font: _regular, fontSize: 11);
    final strong = pw.TextStyle(font: _bold, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final title = pw.TextStyle(font: _bold, fontSize: 16, fontWeight: pw.FontWeight.bold);
    String m(double v) => '${Fmt.num2(v)} $currency';
    String usd(double v, double rate) => Fmt.num2(
        v / rate < 100 ? double.parse((v / rate).toStringAsFixed(2)) : (v / rate).roundToDouble());
    // المبلغ بالليرة وما يعادله بالدولار
    String both(double v, double rate) =>
        rate > 0 ? '${m(v)}  (ما يعادل ${usd(v, rate)}\$)' : m(v);

    pw.Widget kv(String k, String v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k, style: bold ? strong : base),
              pw.Text(v, style: bold ? strong : base),
            ],
          ),
        );

    pw.Widget section(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(t, style: title),
        );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
      ),
      build: (ctx) => [
        pw.Center(child: pw.Text(storeName, style: title)),
        pw.Center(child: pw.Text('تقرير الفترة: ${data.range.label}', style: base)),
        pw.Divider(),
        section('الأرباح'),
        kv('إجمالي المبيعات', m(data.sales)),
        kv('تكلفة البضاعة المباعة', m(data.cost)),
        kv('الربح قبل المصاريف', m(data.grossProfit), bold: true),
        if (data.expensesByCategory.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('خُصم منه:', style: strong),
          for (final c in data.expensesByCategory)
            kv('${c.key} (${data.percentOfExpenses(c.value).toStringAsFixed(0)}%)', m(c.value)),
          kv('إجمالي المصاريف', m(data.expensesTotal), bold: true),
        ],
        pw.Divider(),
        kv('الربح الصافي النهائي', both(data.netProfit, profitRate), bold: true),
        section('الأصناف الأكثر ربحاً'),
        for (final p in data.topByProfit(10)) kv('${p.name} (${p.qty} قطعة)', m(p.profit)),
        section('الأصناف الأكثر مبيعاً'),
        for (final p in data.topByQty(10)) kv(p.name, '${p.qty} قطعة'),
        section('أفضل الزبائن'),
        for (final c in data.topCustomers(10)) kv(c.key, m(c.value)),
        section('رأس المال الحالي'),
        kv('رأس المال كبضاعة (بسعر الشراء)', both(capital.stockBuy, capitalRate)),
        kv('رأس المال كصندوق (درج)', both(capital.cash, capitalRate)),
        pw.Divider(),
        kv('إجمالي رأس المال الكامل (بضاعة + صندوق)', both(capital.stockAndCash, capitalRate),
            bold: true),
        pw.SizedBox(height: 6),
        kv('قيمة البضاعة بسعر البيع', m(capital.stockSell)),
        kv('الربح المتوقع من المخزون', m(capital.expectedProfit)),
        kv('ديون الزبائن (نقدية متوقعة)', m(capital.customersOwed)),
        kv('مستحقات الموردين', m(capital.suppliersOwed)),
      ],
    ));
    return doc.save();
  }

  static Future<void> share(Uint8List bytes, String label) =>
      Printing.sharePdf(bytes: bytes, filename: 'تقرير-$label.pdf');
}
