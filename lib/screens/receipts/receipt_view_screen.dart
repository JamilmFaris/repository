import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/arabic_words.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/receipt_pdf.dart';
import '../../data/models/receipt.dart';
import '../../providers/settings_provider.dart';

/// معاينة وصل الدفع مع الإرسال (واتساب/مشاركة)، PDF، وطباعة.
class ReceiptViewScreen extends StatefulWidget {
  final Receipt receipt;
  const ReceiptViewScreen({super.key, required this.receipt});
  @override
  State<ReceiptViewScreen> createState() => _ReceiptViewScreenState();
}

class _ReceiptViewScreenState extends State<ReceiptViewScreen> {
  final _key = GlobalKey();

  Future<void> _shareImage() async {
    final boundary = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt-${widget.receipt.number}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)],
        text: 'وصل استلام مبلغ رقم ${widget.receipt.number}');
  }

  Future<Uint8List> _pdfBytes() async {
    final s = context.read<SettingsProvider>();
    return ReceiptPdf.build(
      receipt: widget.receipt,
      storeName: s.storeName,
      phone: s.phone,
      currency: s.currency,
    );
  }

  Future<void> _sharePdf() async {
    final bytes = await _pdfBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'receipt-${widget.receipt.number}.pdf',
    );
  }

  Future<void> _print() async {
    final bytes = await _pdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('وصل رقم ${widget.receipt.number}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _key,
            child: ReceiptPaper(receipt: widget.receipt, settings: s),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.send),
              label: const Text('إرسال عبر واتساب', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _print,
                  icon: const Icon(Icons.print),
                  label: const Text('طباعة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ورقة الوصل: ألوان هادئة (أخضر على كريمي) ثابتة حتى في الوضع الليلي.
class ReceiptPaper extends StatelessWidget {
  final Receipt receipt;
  final SettingsProvider settings;
  const ReceiptPaper({super.key, required this.receipt, required this.settings});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D5B);
    const ink = Color(0xFF263238);
    final cur = settings.currency;
    final currencyName = cur == 'ل.س' ? 'ليرة سورية' : cur;

    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$k ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 14, height: 1.5))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green, width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: ink, fontFamily: 'Cairo'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(settings.storeName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            if (settings.phone.isNotEmpty)
              Center(child: Text('هاتف: ${settings.phone}', style: const TextStyle(fontSize: 12))),
            const SizedBox(height: 10),
            const Center(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: green,
                child: Icon(Icons.check, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('وصل استلام مبلغ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: green)),
            ),
            const Divider(color: green, height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('رقم الوصل: ${receipt.number}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${Fmt.date(receipt.date)}  ${Fmt.time(receipt.date)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            line('استلمتُ من السيد:', receipt.customerName),
            line('مبلغاً وقدره:',
                '${Fmt.num2(receipt.amount)} $cur — ${ArabicWords.money(receipt.amount, currencyName: currencyName)}'),
            if (receipt.purpose.isNotEmpty) line('وذلك مقابل:', receipt.purpose),
            if (receipt.note.isNotEmpty) line('ملاحظة:', receipt.note),
            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('التوقيع: ____________________'),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text('شكراً لتعاملكم معنا 🌿',
                  style: TextStyle(color: green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
