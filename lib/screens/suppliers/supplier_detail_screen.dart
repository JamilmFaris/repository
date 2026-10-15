import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/party.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/party_dialogs.dart';
import '../purchases/purchase_invoice_screen.dart';
import 'supplier_return_screen.dart';

class SupplierDetailScreen extends StatelessWidget {
  final int supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final supplier = parties.supplierById(supplierId);
    if (supplier == null) return const Scaffold(body: Center(child: Text('غير موجود')));

    final purchases = parties.purchasesOf(supplierId);
    final payments = parties.supplierPayments.where((p) => p.partyId == supplierId).toList();
    final total = purchases.fold<double>(0, (s, p) => s + p.total);
    final balance = parties.supplierBalance(supplierId);

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final u = await showPartyDialog(context, initial: supplier, title: 'تعديل المورّد');
              if (u != null && context.mounted) await context.read<PartyProvider>().updateSupplier(u);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف المورّد'),
                  content: const Text('تُحذف فواتير شرائه ودفعاته (دون تغيير المخزون). متابعة؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<PartyProvider>().deleteSupplier(supplierId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (supplier.phone.isNotEmpty) _row('الهاتف', supplier.phone),
                  _row('إجمالي المشتريات', Fmt.money(total, cur)),
                  const Divider(),
                  _row(balance < 0 ? 'رصيد لك عنده' : 'المتبقي له',
                      Fmt.money(balance < 0 ? -balance : balance, cur),
                      bold: true, color: balance > 0 ? AppColors.danger : AppColors.success),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('فاتورة شراء'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PurchaseInvoiceScreen(supplierId: supplierId)),
                    );
                    if (context.mounted) await context.read<ProductProvider>().loadProducts();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.payments),
                  label: const Text('تسجيل دفعة'),
                  onPressed: () async {
                    final r = await showAmountDialog(context, title: 'دفعة للمورّد', initial: balance);
                    if (r != null && context.mounted) {
                      await context.read<PartyProvider>().addSupplierPayment(PartyPayment(
                            partyId: supplierId,
                            amount: r.amount,
                            date: DateTime.now(),
                            note: r.note,
                          ));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.assignment_return),
              label: const Text('إرجاع بضاعة لمورّد'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupplierReturnScreen(supplierId: supplierId)),
                );
                if (context.mounted) await context.read<ProductProvider>().loadProducts();
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text('فواتير الشراء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (purchases.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد فواتير')),
          for (final p in purchases)
            Card(
              child: ExpansionTile(
                title: Text('${p.number.isEmpty ? 'فاتورة شراء' : 'فاتورة ${p.number}'} • ${Fmt.date(p.date)}'),
                subtitle: Text(
                    '${Fmt.money(p.total, cur)} • مدفوع ${Fmt.money(p.paidAmount, cur)}'),
                children: [
                  for (final it in p.items)
                    ListTile(
                      dense: true,
                      title: Text(it.productName),
                      subtitle: Text('${it.quantity} × ${Fmt.money(it.buyPrice, cur)}'),
                      trailing: Text(Fmt.money(it.total, cur)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text('مرتجعات للمورّد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (parties.returnsOf(supplierId).isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مرتجعات')),
          for (final r in parties.returnsOf(supplierId))
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_return, color: AppColors.warning),
                title: Text('${r.reason} — ${Fmt.money(r.total, cur)}'),
                subtitle: Text(
                    '${Fmt.date(r.date)} • ${r.items.map((i) => '${i.productName} × ${i.quantity}').join('، ')}'),
              ),
            ),
          const SizedBox(height: 12),
          const Text('الدفعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (payments.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد دفعات')),
          for (final p in payments)
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: AppColors.success),
                title: Text(Fmt.money(p.amount, cur)),
                subtitle: Text('${Fmt.dateTime(p.date)}${p.note.isEmpty ? '' : ' • ${p.note}'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => context.read<PartyProvider>().deleteSupplierPayment(p.id!),
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
        Text(value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: bold ? 16 : 14)),
      ],
    ),
  );
}
