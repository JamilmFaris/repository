import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/pricing.dart';
import '../../data/models/purchase.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

/// فاتورة شراء من مورّد: إدخال بضاعة دفعة واحدة.
class PurchaseInvoiceScreen extends StatefulWidget {
  final int? supplierId;
  const PurchaseInvoiceScreen({super.key, this.supplierId});
  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  int? _supplierId;
  int? _productId;
  DateTime _date = DateTime.now();
  final _number = TextEditingController();
  final _notes = TextEditingController();
  final _paid = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _giftQty = TextEditingController();
  bool _company = false;
  final _ship = TextEditingController();
  final _other = TextEditingController();
  bool _shipUsd = false;
  bool _otherUsd = false;
  final List<PurchaseItem> _items = [];

  @override
  void initState() {
    super.initState();
    _supplierId = widget.supplierId;
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    _paid.dispose();
    _qty.dispose();
    _price.dispose();
    _giftQty.dispose();
    _ship.dispose();
    _other.dispose();
    super.dispose();
  }

  void _error(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.danger));

  void _addItem() {
    final prod = _productId == null ? null : context.read<ProductProvider>().byId(_productId!);
    final qty = (Fmt.parseNum(_qty.text) ?? 0).toInt();
    final price = Fmt.parseNum(_price.text);
    if (prod == null || qty <= 0 || price == null || price < 0) {
      _error('اختر الصنف وأدخل الكمية والسعر');
      return;
    }
    final rate = context.read<SettingsProvider>().dollarBuyRate;
    if (prod.isUsd && rate <= 0) {
      _error('حدّد سعر شراء الدولار من الإعدادات أولاً');
      return;
    }
    // عرض الشركة: السعر المدخل هو ثمن القطع المدفوعة، يوزَّع على (المدفوعة + الهدايا)
    final gifts = _company ? (Fmt.parseNum(_giftQty.text) ?? 0).toInt() : 0;
    if (_company && gifts <= 0) {
      _error('أدخل عدد قطع هدية الشركة');
      return;
    }
    final total = qty + gifts;
    final effective = price * qty / total;
    setState(() {
      _items.add(PurchaseItem(
        productId: prod.id!,
        productName: prod.name,
        quantity: total,
        giftQty: gifts,
        buyPrice: prod.isUsd ? Pricing.usdToSyp(effective, rate) : effective,
        usdPrice: prod.isUsd ? effective : null,
      ));
      _productId = null;
      _qty.text = '1';
      _price.clear();
      _giftQty.clear();
      _company = false;
    });
  }

  Widget _extraRow(String label, TextEditingController c, bool usd,
      ValueChanged<bool> onUsd, String cur) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => Fmt.selectAll(c),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(cur)),
            const ButtonSegment(value: true, label: Text('\$')),
          ],
          selected: {usd},
          onSelectionChanged: (v) => onUsd(v.first),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_supplierId == null || _items.isEmpty) {
      _error('اختر المورّد وأضف صنفاً واحداً على الأقل');
      return;
    }
    // الشحن والجمارك: تُحوَّل للسوري بسعر شراء الدولار إن أُدخلت بالدولار
    final rate = context.read<SettingsProvider>().dollarBuyRate;
    final shipV = Fmt.parseNum(_ship.text) ?? 0;
    final otherV = Fmt.parseNum(_other.text) ?? 0;
    if (((_shipUsd && shipV > 0) || (_otherUsd && otherV > 0)) && rate <= 0) {
      _error('حدّد سعر شراء الدولار من الإعدادات أولاً');
      return;
    }
    final ship = _shipUsd ? shipV * rate : shipV;
    final other = _otherUsd ? otherV * rate : otherV;
    final extra = ship + other;

    // توزيع نسبي حسب قيمة كل سطر: تزيد تكلفة القطعة الفعلية دون زيادة دَين المورّد
    var items = _items;
    if (extra > 0) {
      final base = _items.fold<double>(0, (s, i) => s + i.total);
      items = [
        for (final it in _items)
          () {
            final share = base == 0 ? extra / _items.length : extra * it.total / base;
            return PurchaseItem(
              productId: it.productId,
              productName: it.productName,
              quantity: it.quantity,
              buyPrice: it.buyPrice,
              usdPrice: it.usdPrice,
              giftQty: it.giftQty,
              extraCost: share,
              landedUsd: it.usdPrice != null && rate > 0
                  ? it.usdPrice! + share / it.quantity / rate
                  : null,
            );
          }(),
      ];
    }
    final inv = PurchaseInvoice(
      supplierId: _supplierId!,
      number: _number.text.trim(),
      date: _date,
      paidAmount: Fmt.parseNum(_paid.text) ?? 0,
      notes: _notes.text.trim(),
      items: items,
      shippingCost: ship,
      otherCost: other,
    );
    final parties = context.read<PartyProvider>();
    final products = context.read<ProductProvider>();
    try {
      await parties.addPurchase(inv);
      await products.loadProducts();
    } catch (e) {
      _error('تعذّر الحفظ: $e');
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final products = context.watch<ProductProvider>().products;
    final s = context.watch<SettingsProvider>();
    final total = _items.fold<double>(0, (a, i) => a + i.total);
    final paid = Fmt.parseNum(_paid.text) ?? 0;
    final prod = _productId == null ? null : context.watch<ProductProvider>().byId(_productId!);

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة شراء')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المورّد', border: OutlineInputBorder()),
                  items: parties.suppliers
                      .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _number,
                        decoration: const InputDecoration(
                            labelText: 'رقم فاتورة المورّد', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) {
                            setState(() =>
                                _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'التاريخ', border: OutlineInputBorder()),
                          child: Text(Fmt.date(_date)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                  items: products
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) {
                    final p = context.read<ProductProvider>().byId(v!);
                    setState(() {
                      _productId = v;
                      if (p != null) {
                        final cur = p.isUsd ? p.buyPriceUsd : p.buyPrice;
                        _price.text = cur == cur.roundToDouble() ? '${cur.toInt()}' : '$cur';
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
                        onTap: () => Fmt.selectAll(_qty),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _price,
                        onTap: () => Fmt.selectAll(_price),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'سعر الشراء (${prod != null && prod.isUsd ? '\$' : s.currency})',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _addItem, icon: const Icon(Icons.add)),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🎁 هل فيها عرض شركة؟'),
                  subtitle: const Text('الكمية أعلاه = المدفوعة، والسعر يُوزَّع على المدفوعة + الهدايا'),
                  value: _company,
                  onChanged: (v) => setState(() => _company = v),
                ),
                if (_company)
                  TextField(
                    controller: _giftQty,
                    keyboardType: TextInputType.number,
                    onTap: () => Fmt.selectAll(_giftQty),
                    decoration: const InputDecoration(
                      labelText: 'عدد قطع الهدية (مجانية من الشركة)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('لم تضف أصنافاً بعد', style: TextStyle(color: AppColors.grey))),
                  ),
                for (var i = 0; i < _items.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(_items[i].productName),
                      subtitle: Text(
                          '${_items[i].quantity - _items[i].giftQty}'
                          '${_items[i].giftQty > 0 ? ' + ${_items[i].giftQty} هدية شركة' : ''}'
                          ' × ${Fmt.money(_items[i].buyPrice, s.currency)} (تكلفة فعلية)'
                          '${_items[i].usdPrice != null ? ' (\$${Fmt.num2(_items[i].usdPrice!)})' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Fmt.money(_items[i].total, s.currency),
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
                const Text('تكاليف إضافية (تُدفع نقداً لجهة أخرى وتدخل في تكلفة القطع)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _extraRow('تكلفة الشحن والنقل', _ship, _shipUsd,
                    (v) => setState(() => _shipUsd = v), s.currency),
                const SizedBox(height: 8),
                _extraRow('مصاريف إضافية أخرى (عمولات، تخليص، جمارك)', _other, _otherUsd,
                    (v) => setState(() => _otherUsd = v), s.currency),
                const SizedBox(height: 12),
                TextField(
                  controller: _paid,
                  onTap: () => Fmt.selectAll(_paid),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع للمورّد (${s.currency})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'ملاحظة', border: OutlineInputBorder()),
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
                    const Text('الإجمالي:', style: TextStyle(fontSize: 16)),
                    Text(Fmt.money(total, s.currency),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المتبقي للمورّد:'),
                    Text(Fmt.money((total - paid).clamp(0, double.infinity).toDouble(), s.currency),
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ وإدخال البضاعة', style: TextStyle(fontSize: 16)),
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
