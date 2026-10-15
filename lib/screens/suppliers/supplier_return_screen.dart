import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/purchase.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

/// إرجاع بضاعة (تالفة/غير مطابقة) إلى مورّد: يُخصم من المخزون ومن دَين المورّد.
class SupplierReturnScreen extends StatefulWidget {
  final int supplierId;
  const SupplierReturnScreen({super.key, required this.supplierId});
  @override
  State<SupplierReturnScreen> createState() => _SupplierReturnScreenState();
}

class _SupplierReturnScreenState extends State<SupplierReturnScreen> {
  static const reasons = ['تالف', 'منتهي الصلاحية', 'خطأ في الطلبية', 'أخرى'];

  int? _productId;
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _note = TextEditingController();
  String _reason = reasons.first;
  final List<SupplierReturnItem> _items = [];

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _error(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.danger));

  void _add() {
    final prod = _productId == null ? null : context.read<ProductProvider>().byId(_productId!);
    final qty = (Fmt.parseNum(_qty.text) ?? 0).toInt();
    final price = Fmt.parseNum(_price.text);
    if (prod == null || qty <= 0 || price == null || price < 0) {
      _error('اختر الصنف وأدخل الكمية والسعر');
      return;
    }
    final already = _items.where((i) => i.productId == prod.id).fold<int>(0, (s, i) => s + i.quantity);
    if (qty + already > prod.quantity) {
      _error('الكمية المتوفرة في المخزون ${prod.quantity} فقط');
      return;
    }
    setState(() {
      _items.add(SupplierReturnItem(
        productId: prod.id!,
        productName: prod.name,
        quantity: qty,
        unitPrice: price,
      ));
      _productId = null;
      _qty.text = '1';
      _price.clear();
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      _error('أضف صنفاً واحداً على الأقل');
      return;
    }
    final parties = context.read<PartyProvider>();
    final products = context.read<ProductProvider>();
    final nav = Navigator.of(context);
    await parties.addSupplierReturn(SupplierReturn(
      supplierId: widget.supplierId,
      date: DateTime.now(),
      reason: _reason,
      note: _note.text.trim(),
      items: _items,
    ));
    await products.loadProducts();
    nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final cur = context.watch<SettingsProvider>().currency;
    final total = _items.fold<double>(0, (s, i) => s + i.total);

    return Scaffold(
      appBar: AppBar(title: const Text('إرجاع بضاعة لمورّد')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                      labelText: 'سبب الإرجاع', border: OutlineInputBorder()),
                  items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) => setState(() => _reason = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                  items: [
                    for (final p in products)
                      DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.quantity} متوفر)')),
                  ],
                  onChanged: (v) {
                    final p = context.read<ProductProvider>().byId(v!);
                    setState(() {
                      _productId = v;
                      if (p != null) {
                        _price.text = p.buyPrice == p.buyPrice.roundToDouble()
                            ? '${p.buyPrice.toInt()}'
                            : '${p.buyPrice}';
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        onTap: () => Fmt.selectAll(_qty),
                        decoration: const InputDecoration(
                            labelText: 'الكمية', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () => Fmt.selectAll(_price),
                        decoration: InputDecoration(
                          labelText: 'سعر القطعة ($cur)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _items.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(_items[i].productName),
                      subtitle: Text('${_items[i].quantity} × ${Fmt.money(_items[i].unitPrice, cur)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.money(_items[i].total, cur),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.danger),
                            onPressed: () => setState(() => _items.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('قيمة المرتجع (تُخصم من دَين المورّد):'),
                    Text(Fmt.money(total, cur),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('تأكيد الإرجاع', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
