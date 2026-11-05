import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/product.dart';
import 'formatters.dart';

/// تقارير المخزون: جرد كامل، وتقرير الأصناف المنخفضة والمنتهية (PDF أو صور للواتساب).
class StockPdf {
  static const _teal = PdfColor.fromInt(0xFF0F766E);
  static const _red = PdfColor.fromInt(0xFFDC2626);
  static const _amber = PdfColor.fromInt(0xFFD97706);
  static const _green = PdfColor.fromInt(0xFF16A34A);
  static const _ink = PdfColor.fromInt(0xFF1F2937);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _zebra = PdfColor.fromInt(0xFFF3F7F6);

  static Future<pw.ThemeData> _theme() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static pw.PageTheme _page(pw.ThemeData theme) => pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
      );

  static pw.Widget _header(pw.ThemeData t, String store, String title, PdfColor color) {
    final now = DateTime.now();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(store,
              style: pw.TextStyle(font: t.defaultTextStyle.font, fontSize: 12, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(title,
              style: pw.TextStyle(
                  font: t.defaultTextStyle.font,
                  fontBold: t.defaultTextStyle.fontBold,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 22,
                  color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text('${Fmt.date(now)}  ${Fmt.time(now)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
        ],
      ),
    );
  }

  static pw.Widget _chip(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: color, width: 0.8),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: [
            pw.Text(value,
                style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: color)),
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ),
      );

  /// جدول (الأعمدة بترتيب RTL: الأول من اليمين) بصفوف متناوبة الألوان.
  static pw.Widget _table(List<String> head, List<List<String>> rows, List<double> flex,
      {required PdfColor color, PdfColor Function(int row)? qtyColor, int qtyCol = -1}) {
    pw.Widget cell(String t, {bool header = false, bool first = false, PdfColor? c}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            t,
            textAlign: first ? pw.TextAlign.right : pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: header ? 10.5 : 10.5,
              fontWeight: header || c != null ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: header ? PdfColors.white : (c ?? _ink),
            ),
          ),
        );

    // Table لا يعكس الاتجاه تلقائياً: نعكس الأعمدة يدوياً لتبدأ من اليمين
    List<pw.Widget> line(List<String> v, {bool header = false, int row = 0}) => [
          for (var i = v.length - 1; i >= 0; i--)
            cell(v[i],
                header: header,
                first: i == 1,
                c: !header && i == qtyCol && qtyColor != null ? qtyColor(row) : null),
        ];

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[flex.length - 1 - i]),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(8))),
          repeat: true,
          children: line(head, header: true),
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: r.isOdd ? _zebra : PdfColors.white),
            children: line(rows[r], row: r),
          ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx, String store) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('$store  •  صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _muted)),
      );

  // ------------------------------------------------------------------ جرد كامل

  static Future<Uint8List> buildInventory({
    required List<Product> products,
    required String storeName,
    required int lowThreshold,
  }) async {
    final theme = await _theme();
    final list = [...products]..sort((a, b) => a.name.compareTo(b.name));
    final totalQty = list.fold<int>(0, (s, p) => s + (p.quantity < 0 ? 0 : p.quantity));
    final out = list.where((p) => p.quantity <= 0).length;
    final low = list.where((p) => p.quantity > 0 && p.quantity <= lowThreshold).length;

    String status(Product p) => p.quantity <= 0
        ? 'نفد'
        : (p.quantity <= lowThreshold ? 'منخفض' : 'متوفر');
    PdfColor statusColor(Product p) =>
        p.quantity <= 0 ? _red : (p.quantity <= lowThreshold ? _amber : _green);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _page(theme),
      footer: (ctx) => _footer(ctx, storeName),
      build: (ctx) => [
        _header(theme, storeName, 'تقرير جرد الأصناف', _teal),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _chip('عدد الأصناف', '${list.length}', _teal),
          _chip('إجمالي القطع', Fmt.num2(totalQty), _ink),
          _chip('منخفضة', '$low', _amber),
          _chip('منتهية', '$out', _red),
        ]),
        pw.SizedBox(height: 14),
        _table(
          ['#', 'الصنف', 'الكمية المتوفرة', 'الحالة'],
          [
            for (var i = 0; i < list.length; i++)
              [
                '${i + 1}',
                list[i].name,
                '${list[i].quantity}',
                status(list[i]),
              ],
          ],
          [1, 6, 2.4, 2],
          color: _teal,
          qtyCol: 3,
          qtyColor: (r) => statusColor(list[r]),
        ),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------- المنخفضة والمنتهية

  static Future<Uint8List> buildAlerts({
    required List<Product> products,
    required String storeName,
    required int lowThreshold,
  }) async {
    final theme = await _theme();
    final out = products.where((p) => p.quantity <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final low = products.where((p) => p.quantity > 0 && p.quantity <= lowThreshold).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));

    pw.Widget section(String title, String sub, PdfColor color, PdfColor tint, List<Product> items) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: tint,
                border: pw.Border(right: pw.BorderSide(color: color, width: 4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
                  pw.Text('${items.length} صنف', style: pw.TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 6),
            if (items.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('لا توجد أصناف في هذه الفئة ✓',
                    style: const pw.TextStyle(fontSize: 11, color: _muted)),
              )
            else
              _table(
                ['#', 'الصنف', 'المتبقي'],
                [
                  for (var i = 0; i < items.length; i++)
                    ['${i + 1}', items[i].name, items[i].quantity <= 0 ? 'نفد' : '${items[i].quantity}'],
                ],
                [1, 7, 2.2],
                color: color,
                qtyCol: 2,
                qtyColor: (_) => color,
              ),
            pw.SizedBox(height: 16),
          ],
        );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _page(theme),
      footer: (ctx) => _footer(ctx, storeName),
      build: (ctx) => [
        _header(theme, storeName, 'تقرير النواقص والأصناف المنتهية', _red),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          _chip('أصناف منتهية', '${out.length}', _red),
          _chip('أصناف منخفضة', '${low.length}', _amber),
          _chip('المطلوب إعادة طلبه', '${out.length + low.length}', _teal),
        ]),
        pw.SizedBox(height: 16),
        section('أصناف نفدت تماماً', 'الكمية صفر — تحتاج إعادة طلب عاجلة', _red, const PdfColor.fromInt(0xFFFEE2E2), out),
        section('أصناف قاربت على النفاد', 'الكمية $lowThreshold قطع أو أقل', _amber, const PdfColor.fromInt(0xFFFEF3C7), low),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------------------- مشاركة

  static Future<void> sharePdf(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  /// يحوّل التقرير إلى صور PNG (صفحة لكل صورة) ويرسلها عبر المشاركة (واتساب...).
  static Future<void> shareAsImages(Uint8List pdfBytes, String name, {String? text}) async {
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    var i = 1;
    await for (final page in Printing.raster(pdfBytes, dpi: 144)) {
      final png = await page.toPng();
      final f = File('${dir.path}/$name-$i.png');
      await f.writeAsBytes(png);
      files.add(XFile(f.path));
      i++;
    }
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: text);
  }
}
