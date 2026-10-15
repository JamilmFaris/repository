import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/product.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/motion.dart';
import '../../widgets/price_lock_sheet.dart';
import '../../widgets/product_card.dart';
import 'add_edit_product_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProductProvider>();
    final inv = context.watch<InvoiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final report = context.read<ReportProvider>()..update(inv.invoices, p.products);

    final soldMap = report.soldQtyByProduct;
    final profitMap = report.profitByProduct;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('الأصناف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context, p),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
        icon: const Icon(Icons.add),
        label: const Text('صنف جديد'),
      ),
      body: Column(
        children: [
          if (p.lowStockFor(settings.lowStock).isNotEmpty || p.outOfStock.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.warning.withOpacity(0.15),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: ${p.lowStockFor(settings.lowStock).length} صنف منخفض و ${p.outOfStock.length} صنف منتهي',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: p.setSearch,
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: p.products.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'لا توجد أصناف', subtitle: 'أضف صنفك الأول من الزر أدناه')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: p.products.length,
                    itemBuilder: (_, i) {
                      final prod = p.products[i];
                      return FadeSlideIn(
                        index: i,
                        child: ProductCard(
                        product: prod,
                        currency: settings.currency,
                        lowThreshold: settings.lowStock,
                        onLock: prod.isUsd ? () => showPriceLockSheet(context, prod) : null,
                        soldQty: soldMap[prod.id] ?? 0,
                        totalProfit: profitMap[prod.id] ?? 0,
                        onQuantityChanged: (q) => p.updateQuantity(prod, q),
                        onEdit: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddEditProductScreen(product: prod))),
                        onDelete: () => _confirmDelete(context, p, prod),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context, ProductProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ترتيب حسب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(value: 'name', groupValue: 'name', onChanged: (_) {}, title: const Text('الاسم')),
            RadioListTile(value: 'quantity', groupValue: 'name', onChanged: (_) {}, title: const Text('الكمية')),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductProvider p, Product prod) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${prod.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () { p.delete(prod.id!); Navigator.pop(context); },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}