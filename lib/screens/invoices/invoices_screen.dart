import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'create_invoice_screen.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final products = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          );
          if (result == true) {
            await context.read<ProductProvider>().loadProducts();
            await context.read<InvoiceProvider>().loadInvoices();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
      body: inv.invoices.isEmpty
          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'لا توجد فواتير', subtitle: 'ابدأ بإنشاء فاتورة جديدة')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: inv.invoices.length,
              itemBuilder: (_, i) {
                final invoice = inv.invoices[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.receipt, color: AppColors.primary),
                    ),
                    title: Text(invoice.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${invoice.number} • ${Fmt.date(invoice.date)}'),
                        Text('${invoice.items.length} صنف • ${Fmt.money(invoice.total, settings.currency)}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id!))),
                  ),
                );
              },
            ),
    );
  }
}