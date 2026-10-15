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
  final _coBuy = TextEditingController();
  final _coFree = TextEditingController();
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
      if (p.hasCompanyOffer) {
        _coBuy.text = '${p.companyBuyQty}';
        _coFree.text = '${p.companyFreeQty}';
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
    final st = context.read<SettingsProvider>();
    final buyRate = st.dollarBuyRate, sellRate = st.dollarRate;
    if (_usd && (buyRate <= 0 || sellRate <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد سعري شراء وبيع الدولار من الإعدادات أولاً')),
      );
      return;
    }
    final buy = _parse(_buy), sell = _parse(_sell);
    final offerBuy = int.tryParse(_latin(_offerBuy.text)) ?? 0;
    final offerFree = int.tryParse(_latin(_offerFree.text)) ?? 0;
    final hasOffer = offerBuy > 0 && offerFree > 0;
    final coBuy = int.tryParse(_latin(_coBuy.text)) ?? 0;
    final coFree = int.tryParse(_latin(_coFree.text)) ?? 0;
    final hasCo = coBuy > 0 && coFree > 0;
    final old = widget.product;
    // السعر المثبّت يبقى كما هو ما لم يُعدَّل رقمه بالدولار صراحةً
    final keepBuy = old != null && _usd && old.isUsd && old.buyLocked && old.buyPriceUsd == buy;
    final keepSell = old != null && _usd && old.isUsd && old.sellLocked && old.sellPriceUsd == sell;
    final p = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      quantity: int.parse(_latin(_qty.text)),
      buyPrice: !_usd ? buy : (keepBuy ? old.buyPrice : Pricing.usdToSyp(buy, buyRate)),
      sellPrice: !_usd ? sell : (keepSell ? old.sellPrice : Pricing.usdToSyp(sell, sellRate)),
      createdAt: widget.product?.createdAt,
      priceMode: _usd ? 'USD' : 'SYP',
      buyPriceUsd: _usd ? buy : 0,
      sellPriceUsd: _usd ? sell : 0,
      offerBuyQty: hasOffer ? offerBuy : 0,
      offerFreeQty: hasOffer ? offerFree : 0,
      companyBuyQty: hasCo ? coBuy : 0,
      companyFreeQty: hasCo ? coFree : 0,
      lockMode: _usd ? (old?.lockMode ?? 'none') : 'none',
      lockBuyRate: old?.lockBuyRate ?? 0,
      lockSellRate: old?.lockSellRate ?? 0,
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
              TextFormField(controller: _qty, onTap: () => Fmt.selectAll(_qty), keyboardType: TextInputType.number,
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
              TextFormField(controller: _buy, onTap: () => Fmt.selectAll(_buy), keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر الشراء ($unit)', border: const OutlineInputBorder()),
                validator: (v) => double.tryParse(_latin(v ?? '')) == null ? 'رقم مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _sell, onTap: () => Fmt.selectAll(_sell), keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر المبيع ($unit)', border: const OutlineInputBorder()),
                validator: (v) => double.tryParse(_latin(v ?? '')) == null ? 'رقم مطلوب' : null),
              if (_usd) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    (s.dollarRate <= 0 || s.dollarBuyRate <= 0)
                        ? 'لم يُحدَّد سعرا الدولار بعد (من الإعدادات)'
                        : 'بالسوري: '
                          'شراء ${Fmt.money(Pricing.usdToSyp(_parse(_buy), s.dollarBuyRate), s.currency)}'
                          ' (بسعر ${Fmt.num2(s.dollarBuyRate)})'
                          ' — مبيع ${Fmt.money(Pricing.usdToSyp(_parse(_sell), s.dollarRate), s.currency)}'
                          ' (بسعر ${Fmt.num2(s.dollarRate)})',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('🎁 عرض على حسابي: كل N مباعة ← M هدية (أدفع ثمنها أنا)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(controller: _offerBuy, onTap: () => Fmt.selectAll(_offerBuy), keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مع كل (N)', border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(controller: _offerFree, onTap: () => Fmt.selectAll(_offerFree), keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'هدية (M)', border: OutlineInputBorder())),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('🎁 عرض الشركة: كل N مباعة ← M هدية (تدفع الشركة ثمنها)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(controller: _coBuy, onTap: () => Fmt.selectAll(_coBuy), keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مع كل (N)', border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(controller: _coFree, onTap: () => Fmt.selectAll(_coFree), keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'هدية (M)', border: OutlineInputBorder())),
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
