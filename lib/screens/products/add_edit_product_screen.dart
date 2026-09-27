import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AddEditProductScreen({super.key, this.product});
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _name.text = widget.product!.name;
      _qty.text = widget.product!.quantity.toString();
      _buy.text = widget.product!.buyPrice.toString();
      _sell.text = widget.product!.sellPrice.toString();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      quantity: int.parse(_qty.text),
      buyPrice: double.parse(_buy.text),
      sellPrice: double.parse(_sell.text),
    );
    final provider = context.read<ProductProvider>();
    if (widget.product == null) {
      await provider.add(p);
    } else {
      await provider.update(p);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'إضافة صنف' : 'تعديل صنف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الصنف', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _qty, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                validator: (v) => int.tryParse(v ?? '') == null ? 'رقم صحيح مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _buy, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()),
                validator: (v) => double.tryParse(v ?? '') == null ? 'رقم مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _sell, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر المبيع', border: OutlineInputBorder()),
                validator: (v) => double.tryParse(v ?? '') == null ? 'رقم مطلوب' : null),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(onPressed: _save, child: const Text('حفظ', style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}