import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_item.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});
  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _customer = TextEditingController();
  DateTime _date = DateTime.now();
  final List<InvoiceItem> _items = [];
  int? _selectedProductId;
  final _qtyCtrl = TextEditingController(text: '1');

  Future<void> _addItem() async {
    if (_selectedProductId == null) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    final prod = context.read<ProductProvider>().byId(_selectedProductId!);
    if (qty > prod.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الكمية المتوفرة ${prod.quantity} فقط'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() {
      _items.add(InvoiceItem(
        productId: prod.id!,
        productName: prod.name,
        quantity: qty,
        buyPrice: prod.buyPrice,
        sellPrice: prod.sellPrice,
      ));
      _qtyCtrl.text = '1';
      _selectedProductId = null;
    });
  }

  Future<void> _save() async {
    if (_customer.text.trim().isEmpty || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الزبون وأضف صنفاً واحداً على الأقل'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final invProvider = context.read<InvoiceProvider>();
    final prodProvider = context.read<ProductProvider>();
    final number = await invProvider.nextNumber();

    // خصم الكميات
    for (final it in _items) {
      final prod = prodProvider.byId(it.productId);
      prod.quantity -= it.quantity;
      await prodProvider.update(prod);
    }

    await invProvider.add(Invoice(
      number: number,
      customerName: _customer.text.trim(),
      date: _date,
      items: _items,
    ));

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final settings = context.watch<SettingsProvider>();
    final total = _items.fold<double>(0, (s, i) => s + i.totalSell);

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة جديدة')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _customer,
                  decoration: const InputDecoration(labelText: 'اسم الزبون', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _date,
                        firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'التاريخ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                    child: Text(Fmt.date(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                  items: products.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (${p.quantity} متوفر)'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('الأصناف المضافة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Padding(padding: EdgeInsets.all(24),
                    child: Center(child: Text('لم تضف أصنافاً بعد', style: TextStyle(color: AppColors.grey))))
                else
                  ..._items.asMap().entries.map((e) {
                    final idx = e.key; final it = e.value;
                    return Card(
                      child: ListTile(
                        title: Text(it.productName),
                        subtitle: Text('${it.quantity} × ${Fmt.money(it.sellPrice, settings.currency)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Fmt.money(it.totalSell, settings.currency),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.danger),
                              onPressed: () => setState(() => _items.removeAt(idx)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي:', style: TextStyle(fontSize: 16)),
                    Text(Fmt.money(total, settings.currency),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الفاتورة', style: TextStyle(fontSize: 16)),
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