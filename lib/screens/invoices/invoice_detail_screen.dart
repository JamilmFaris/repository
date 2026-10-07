import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/invoice_pdf.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>().byId(invoiceId);
    final settings = context.watch<SettingsProvider>();

    if (inv == null) return const Scaffold(body: Center(child: Text('غير موجود')));

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.number),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => InvoicePdf.generateAndShare(inv, settings),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('الزبون', inv.customerName),
                  _row('التاريخ', Fmt.date(inv.date)),
                  _row('عدد الأصناف', '${inv.items.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('الأصناف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...inv.items.map((it) => Card(
            child: ListTile(
              title: Text(it.productName),
              subtitle: Text('${it.quantity} × ${Fmt.money(it.sellPrice, settings.currency)}'),
              trailing: Text(Fmt.money(it.totalSell, settings.currency),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )),
          const SizedBox(height: 16),
          Card(
            color: AppColors.success.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('الإجمالي', Fmt.money(inv.total, settings.currency)),
                  _row('التكلفة', Fmt.money(inv.totalCost, settings.currency)),
                  const Divider(),
                  _row('الربح', Fmt.money(inv.totalProfit, settings.currency), bold: true, color: AppColors.success),
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
              final inv = context.read<InvoiceProvider>().byId(id);
              final prod = context.read<ProductProvider>();
              if (inv != null) {
                for (final it in inv.items) {
                  final p = prod.byId(it.productId);
                  if (p == null) continue;
                  p.quantity += it.quantity;
                  await prod.update(p);
                }
              }
              await context.read<InvoiceProvider>().delete(id);
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