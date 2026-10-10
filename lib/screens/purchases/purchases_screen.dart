import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'purchase_invoice_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = parties.purchases;

    return Scaffold(
      appBar: AppBar(title: const Text('فواتير الشراء')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (parties.suppliers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('أضف مورّداً أولاً من قائمة الموردين')));
            return;
          }
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PurchaseInvoiceScreen()));
          if (context.mounted) await context.read<ProductProvider>().loadProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text('فاتورة شراء'),
      ),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'لا توجد فواتير شراء',
              subtitle: 'أدخل بضاعتك الجديدة دفعة واحدة من فاتورة شراء')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                final supplier = parties.supplierById(p.supplierId);
                return Card(
                  child: ExpansionTile(
                    title: Text(supplier?.name ?? 'مورّد محذوف',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${p.number.isEmpty ? '' : '${p.number} • '}${Fmt.date(p.date)} • ${Fmt.money(p.total, cur)}'
                        '${p.remaining > 0 ? ' • متبقي ${Fmt.money(p.remaining, cur)}' : ''}'),
                    children: [
                      for (final it in p.items)
                        ListTile(
                          dense: true,
                          title: Text(it.productName),
                          subtitle: Text('${it.quantity} × ${Fmt.money(it.buyPrice, cur)}'),
                          trailing: Text(Fmt.money(it.total, cur)),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        label: const Text('حذف الفاتورة (تُنقَص الكميات)',
                            style: TextStyle(color: AppColors.danger)),
                        onPressed: () async {
                          final prods = context.read<ProductProvider>();
                          await context.read<PartyProvider>().deletePurchase(p.id!);
                          await prods.loadProducts();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
