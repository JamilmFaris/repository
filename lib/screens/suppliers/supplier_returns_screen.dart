import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';

/// سجل مرتجعات الموردين: التاريخ، المورّد، الأصناف، السبب، المبلغ.
class SupplierReturnsScreen extends StatelessWidget {
  const SupplierReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = parties.supplierReturns;

    return Scaffold(
      appBar: AppBar(title: const Text('مرتجعات الموردين')),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.assignment_return_outlined,
              title: 'لا توجد مرتجعات',
              subtitle: 'يظهر هنا كل ما أرجعتَه للموردين')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final r = list[i];
                final supplier = parties.supplierById(r.supplierId);
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.assignment_return, color: AppColors.warning),
                    title: Text('إرجاع لمورّد — ${supplier?.name ?? 'محذوف'}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${Fmt.date(r.date)} • ${r.reason} • ${Fmt.money(r.total, cur)}'),
                    children: [
                      for (final it in r.items)
                        ListTile(
                          dense: true,
                          title: Text(it.productName),
                          subtitle: Text('${it.quantity} × ${Fmt.money(it.unitPrice, cur)}'),
                          trailing: Text(Fmt.money(it.total, cur)),
                        ),
                      if (r.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('ملاحظة: ${r.note}')),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        label: const Text('حذف المرتجع (تعود الكميات والدَّين)',
                            style: TextStyle(color: AppColors.danger)),
                        onPressed: () async {
                          final prods = context.read<ProductProvider>();
                          await context.read<PartyProvider>().deleteSupplierReturn(r.id!);
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
