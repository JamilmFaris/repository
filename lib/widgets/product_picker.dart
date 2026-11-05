import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../data/models/product.dart';

/// حقل اختيار صنف: يفتح نافذة بحث فوري بدل القائمة المنسدلة الطويلة.
class ProductPickerField extends StatelessWidget {
  final List<Product> products;
  final int? selectedId;
  final ValueChanged<Product> onSelected;
  final String label;

  /// نص إضافي يُلحق باسم الصنف في القائمة (مثل الكمية المتوفرة والعروض).
  final String Function(Product p)? detail;

  const ProductPickerField({
    super.key,
    required this.products,
    required this.selectedId,
    required this.onSelected,
    this.label = 'الصنف',
    this.detail,
  });

  Product? get _selected {
    for (final p in products) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final p = await showProductPicker(context, products, detail: detail);
        if (p != null) onSelected(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          sel?.name ?? 'اضغط للبحث عن صنف...',
          overflow: TextOverflow.ellipsis,
          style: sel == null ? const TextStyle(color: AppColors.grey) : null,
        ),
      ),
    );
  }
}

Future<Product?> showProductPicker(
  BuildContext context,
  List<Product> products, {
  String Function(Product p)? detail,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ProductPickerSheet(products: products, detail: detail),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  final String Function(Product p)? detail;
  const _ProductPickerSheet({required this.products, this.detail});
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final list = q.isEmpty
        ? widget.products
        : widget.products.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'اكتب اسم الصنف...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('لا يوجد صنف بهذا الاسم', style: TextStyle(color: AppColors.grey)))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        final out = p.quantity <= 0;
                        return ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            widget.detail?.call(p) ?? '${p.quantity} متوفر',
                            style: TextStyle(color: out ? AppColors.danger : AppColors.grey),
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
