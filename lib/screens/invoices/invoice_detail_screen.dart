import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_pdf.dart';
import '../../core/utils/invoice_text.dart';
import '../../data/models/invoice_item.dart';
import '../../data/repositories/invoice_repository.dart';
import 'create_invoice_screen.dart';
import '../../data/models/invoice.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _paperKey = GlobalKey();

  Future<void> _shareImage(Invoice inv) async {
    final boundary = _paperKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoice-${inv.number}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>().byId(widget.invoiceId);
    final settings = context.watch<SettingsProvider>();
    final refund = inv == null ? 0.0 : context.watch<InvoiceProvider>().refundOf(inv.id!);

    if (inv == null) return const Scaffold(body: Center(child: Text('غير موجود')));

    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة ${inv.number}'),
        actions: [
          IconButton(
            tooltip: 'مشاركة PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => InvoicePdf.generateAndShare(inv, settings),
          ),
          IconButton(
            tooltip: 'مشاركة كصورة',
            icon: const Icon(Icons.image),
            onPressed: () => _shareImage(inv),
          ),
          IconButton(
            tooltip: 'تعديل الفاتورة',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateInvoiceScreen(editing: inv)),
            ),
          ),
          IconButton(
            tooltip: 'مرتجع',
            icon: const Icon(Icons.assignment_return),
            onPressed: () => _returnDialog(context, inv),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, inv.id!),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _paperKey,
            child: _Paper(inv: inv, settings: settings),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.success.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('التكلفة', Fmt.money(inv.totalCost, settings.currency)),
                  if (inv.giftCost > 0)
                    _row('تكلفة الهدايا (مصاريف العروض)',
                        Fmt.money(inv.giftCost, settings.currency)),
                  if (refund > 0)
                    _row('مبلغ مسترجع للمرتجعات', Fmt.money(refund, settings.currency)),
                  const Divider(),
                  _row('الربح', Fmt.money(inv.totalProfit, settings.currency),
                      bold: true, color: AppColors.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: bold ? 16 : 14)),
      ],
    ),
  );

  Future<void> _returnDialog(BuildContext context, Invoice inv) async {
    final cur = context.read<SettingsProvider>().currency;
    final lines = inv.items.where((i) => i.keptQty > 0).toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لا توجد كميات لإرجاعها')));
      return;
    }
    final qty = {for (final l in lines) l.id!: 0};
    final result = await showDialog<List<ReturnLine>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          double refundOf(InvoiceItem it, int q) {
            if (it.keptQty == 0) return 0;
            return inv.netOf(it) / it.keptQty * q;
          }

          final total = lines.fold<double>(0, (s, l) => s + refundOf(l, qty[l.id!]!));
          return AlertDialog(
            title: const Text('مرتجع'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(invoiceItemName(l)),
                      subtitle: Text('المتبقي ${l.keptQty}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty[l.id!]! > 0
                                ? () => setD(() => qty[l.id!] = qty[l.id!]! - 1)
                                : null,
                          ),
                          Text('${qty[l.id!]}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: qty[l.id!]! < l.keptQty
                                ? () => setD(() => qty[l.id!] = qty[l.id!]! + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text('المبلغ المسترجع: ${Fmt.money(total, cur)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              TextButton(
                onPressed: qty.values.every((q) => q == 0)
                    ? null
                    : () => Navigator.pop(ctx, [
                          for (final l in lines)
                            if (qty[l.id!]! > 0)
                              ReturnLine(l, qty[l.id!]!, refundOf(l, qty[l.id!]!)),
                        ]),
                child: const Text('تأكيد المرتجع'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final products = context.read<ProductProvider>();
    await context.read<InvoiceProvider>().returnItems(inv.id!, result);
    await products.loadProducts();
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('سيتم إرجاع الكميات إلى المخزون. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final products = context.read<ProductProvider>();
              await context.read<InvoiceProvider>().delete(id);
              await products.loadProducts();
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// ورقة الفاتورة كما ستظهر في الـPDF/الصورة (ثابتة بيضاء حتى في الوضع الليلي).
class _Paper extends StatelessWidget {
  final Invoice inv;
  final SettingsProvider settings;
  const _Paper({required this.inv, required this.settings});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1E293B);
    const line = Color(0xFF94A3B8);
    final cur = settings.currency;

    Widget cell(String t, {int flex = 1, bool head = false, TextAlign align = TextAlign.center}) => Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: head ? const Color(0xFFE2E8F0) : null,
          border: Border.all(color: line, width: 0.5),
        ),
        child: Text(t,
            textAlign: align,
            style: TextStyle(
                color: ink, fontSize: 12, fontWeight: head ? FontWeight.bold : FontWeight.normal)),
      ),
    );

    Widget tableRow(String total, String name, String qty, String price, {bool head = false}) =>
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell(total, flex: 3, head: head),
              cell(name, flex: 5, head: head, align: TextAlign.right),
              cell(qty, flex: 2, head: head),
              cell(price, flex: 3, head: head),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
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
            if (settings.address.isNotEmpty)
              Center(child: Text(settings.address, style: const TextStyle(fontSize: 12))),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('رقم الفاتورة: ${inv.number}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${Fmt.date(inv.date)}  ${Fmt.time(inv.date)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text('الصيدلاني/ة المحترم/ة: ${inv.customerName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            tableRow('القيمة الإجمالية', 'البيان', 'العدد', 'السعر', head: true),
            ...inv.items.map((it) {
              final note = invoiceItemNote(it, cur);
              return tableRow(Fmt.num2(it.totalSell),
                  note == null ? invoiceItemName(it) : '${invoiceItemName(it)}\n$note',
                  '${it.quantity}', Fmt.num2(it.sellPrice));
            }),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: line, width: 0.5),
              ),
              child: Column(
                children: [
                  if (inv.totalDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموع الكلي قبل الخصم', style: TextStyle(fontSize: 13)),
                        Text('${Fmt.num2(inv.grossTotal)} $cur', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                              'الخصم'
                              '${inv.discountType == 'percent' ? ' (فاتورة ${Fmt.num2(inv.discountValue)}%)' : ''}'
                              '${inv.couponCode != null ? ' - كوبون ${inv.couponCode}' : ''}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text('- ${Fmt.num2(inv.totalDiscount)} $cur',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 14),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(inv.totalDiscount > 0 ? 'المجموع الكلي بعد الخصم' : 'المجموع',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${Fmt.num2(inv.total)} $cur',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ],
              ),
            ),
            if (inv.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('ملاحظة: ${inv.notes}', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
