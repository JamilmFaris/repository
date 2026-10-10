import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pricing.dart';
import '../../data/models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

/// تحويل الأرقام العربية (٠-٩) إلى لاتينية وتوحيد الفاصلة العشرية.
String _latin(String v) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in v.trim().split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : (ch == '٫' || ch == ',' ? '.' : ch));
  }
  return b.toString();
}

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
  final _offerBuy = TextEditingController();
  final _offerFree = TextEditingController();
  bool _usd = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _qty.text = p.quantity.toString();
      _usd = p.isUsd;
      _buy.text = _plain(_usd ? p.buyPriceUsd : p.buyPrice);
      _sell.text = _plain(_usd ? p.sellPriceUsd : p.sellPrice);
      if (p.hasOffer) {
        _offerBuy.text = '${p.offerBuyQty}';
        _offerFree.text = '${p.offerFreeQty}';
      }
    }
    _buy.addListener(() => setState(() {}));
    _sell.addListener(() => setState(() {}));
  }

  /// رقم بدون فواصل آلاف (ليبقى قابلاً للتعديل والقراءة).
  String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double _parse(TextEditingController c) => double.tryParse(_latin(c.text)) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final rate = context.read<SettingsProvider>().dollarRate;
    if (_usd && rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد سعر الدولار من الإعدادات أولاً')),
      );
      return;
    }
    final buy = _parse(_buy), sell = _parse(_sell);
    final offerBuy = int.tryParse(_latin(_offerBuy.text)) ?? 0;
    final offerFree = int.tryParse(_latin(_offerFree.text)) ?? 0;
    final hasOffer = offerBuy > 0 && offerFree > 0;
    final p = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      quantity: int.parse(_latin(_qty.text)),
      buyPrice: _usd ? Pricing.usdToSyp(buy, rate) : buy,
      sellPrice: _usd ? Pricing.usdToSyp(sell, rate) : sell,
      createdAt: widget.product?.createdAt,
      priceMode: _usd ? 'USD' : 'SYP',
      buyPriceUsd: _usd ? buy : 0,
      sellPriceUsd: _usd ? sell : 0,
      offerBuyQty: hasOffer ? offerBuy : 0,
      offerFreeQty: hasOffer ? offerFree : 0,
    );
    final provider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.product == null) {
        await provider.add(p);
      } else {
        await provider.update(p);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذّر الحفظ: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final unit = _usd ? '\$' : s.currency;
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'إضافة صنف' : 'تعديل صنف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الصنف', border: OutlineInputBorder()),
                validator: (v) => v!.trim().isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _qty, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                validator: (v) => int.tryParse(_latin(v ?? '')) == null ? 'رقم صحيح مطلوب' : null),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('الأسعار بالسوري')),
                  ButtonSegment(value: true, label: Text('الأسعار بالدولار')),
                ],
                selected: {_usd},
                onSelectionChanged: (v) => setState(() => _usd = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _buy, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر الشراء ($unit)', border: const OutlineInputBorder()),
                validator: (v) => double.tryParse(_latin(v ?? '')) == null ? 'رقم مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _sell, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر المبيع ($unit)', border: const OutlineInputBorder()),
                validator: (v) => double.tryParse(_latin(v ?? '')) == null ? 'رقم مطلوب' : null),
              if (_usd) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    s.dollarRate <= 0
                        ? 'لم يُحدَّد سعر الدولار بعد (من الإعدادات)'
                        : 'بالسوري (سعر الدولار ${Fmt.num2(s.dollarRate)}): '
                          'شراء ${Fmt.money(Pricing.usdToSyp(_parse(_buy), s.dollarRate), s.currency)}'
                          ' — مبيع ${Fmt.money(Pricing.usdToSyp(_parse(_sell), s.dollarRate), s.currency)}',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('عرض (اختياري): مع كل N قطع مباعة، M مجاناً', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(controller: _offerBuy, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مع كل (N)', border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(controller: _offerFree, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مجاناً (M)', border: OutlineInputBorder())),
                  ),
                ],
              ),
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
