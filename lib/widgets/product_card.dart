import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onDelete;
  final Function(int) onQuantityChanged;
  final VoidCallback onEdit;
  final int soldQty;
  final double totalProfit;
  final String currency;

  const ProductCard({
    super.key,
    required this.product,
    required this.onDelete,
    required this.onQuantityChanged,
    required this.onEdit,
    required this.soldQty,
    required this.totalProfit,
    required this.currency,
  });

  Color get _statusColor {
    if (product.quantity <= 0) return AppColors.danger;
    if (product.quantity <= 5) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2, color: _statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(product.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete, color: AppColors.danger), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip('الكمية', '${product.quantity}', _statusColor),
                const SizedBox(width: 8),
                _chip('شراء', Fmt.money(product.buyPrice, currency), AppColors.grey),
                const SizedBox(width: 8),
                _chip('مبيع', Fmt.money(product.sellPrice, currency), AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _stat('مباع', '$soldQty', Icons.sell)),
                Expanded(child: _stat('ربح', Fmt.money(totalProfit, currency), Icons.trending_up, color: AppColors.success)),
                Expanded(child: _stat('مخزون', Fmt.money(product.buyPrice * product.quantity, currency), Icons.warehouse)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: product.quantity > 0 ? () => onQuantityChanged(product.quantity - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.danger,
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _editQuantity(context),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 72),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${product.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton(
                  onPressed: () => onQuantityChanged(product.quantity + 1),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.success,
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantity(BuildContext context) async {
    final c = TextEditingController(text: '${product.quantity}');
    Fmt.selectAll(c);
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('كمية ${product.name}'),
        content: TextField(
          controller: c,
          autofocus: true,
          onTap: () => Fmt.selectAll(c),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (v != null && v >= 0) onQuantityChanged(v);
  }

  Widget _chip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _stat(String label, String value, IconData icon, {Color? color}) => Column(
    children: [
      Icon(icon, size: 16, color: color ?? AppColors.grey),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
    ],
  );
}