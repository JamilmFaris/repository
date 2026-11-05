import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/stock_pdf.dart';
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

    final low = settings.lowStock;
    final out = p.products.where((x) => x.quantity <= 0).toList();
    final atMin = p.products.where((x) => x.quantity > 0 && x.quantity <= low).toList();

    Widget list(List<Product> items, {required String emptyTitle, required String emptySub}) {
      if (items.isEmpty) {
        return EmptyState(icon: Icons.inventory_2_outlined, title: emptyTitle, subtitle: emptySub);
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final prod = items[i];
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
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('الأصناف'),
          actions: [
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () => _showSortDialog(context, p),
            ),
            PopupMenuButton<String>(
              tooltip: 'تقارير المخزون',
              icon: const Icon(Icons.picture_as_pdf),
              onSelected: (v) => _report(context, v, p, settings),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'inventory', child: Text('جرد كل الأصناف (PDF)')),
                PopupMenuItem(value: 'alerts', child: Text('المنخفضة والمنتهية (PDF)')),
                PopupMenuItem(value: 'alerts-img', child: Text('المنخفضة والمنتهية (صورة / واتساب)')),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'الكل (${p.products.length})'),
              Tab(text: 'المنتهي (${out.length})'),
              Tab(text: 'المنخفض (${atMin.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
          icon: const Icon(Icons.add),
          label: const Text('صنف جديد'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: p.setSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  list(p.products,
                      emptyTitle: 'لا توجد أصناف', emptySub: 'أضف صنفك الأول من الزر أدناه'),
                  list(out, emptyTitle: 'لا توجد أصناف منتهية', emptySub: 'كل أصنافك متوفرة 👌'),
                  list(atMin,
                      emptyTitle: 'لا توجد أصناف منخفضة',
                      emptySub: 'لا صنف وصل للحد الأدنى ($low قطع أو أقل)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report(
      BuildContext context, String kind, ProductProvider p, SettingsProvider settings) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final all = p.allProducts;
      if (all.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('لا توجد أصناف لإصدار التقرير')));
        return;
      }
      if (kind == 'inventory') {
        final bytes = await StockPdf.buildInventory(
            products: all, storeName: settings.storeName, lowThreshold: settings.lowStock);
        await StockPdf.sharePdf(bytes, 'inventory-report.pdf');
      } else {
        final bytes = await StockPdf.buildAlerts(
            products: all, storeName: settings.storeName, lowThreshold: settings.lowStock);
        if (kind == 'alerts') {
          await StockPdf.sharePdf(bytes, 'stock-alerts.pdf');
        } else {
          await StockPdf.shareAsImages(bytes, 'stock-alerts', text: 'تقرير النواقص والأصناف المنتهية');
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر إنشاء التقرير: $e')));
    }
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