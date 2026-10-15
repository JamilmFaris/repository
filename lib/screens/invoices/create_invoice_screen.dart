import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_item.dart';
import '../../data/models/party.dart';
import '../../data/models/product.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/coupon_repository.dart';
import '../../providers/party_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

/// إنشاء فاتورة جديدة، أو تعديل فاتورة محفوظة عند تمرير [editing].
class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? editing;

  /// تحويل حجز إلى فاتورة: الاسم والأصناف تُعبَّأ مسبقاً، ويُغلق الحجز عند الحفظ.
  final Reservation? fromReservation;
  const CreateInvoiceScreen({super.key, this.editing, this.fromReservation});
  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _customer = TextEditingController();
  final _number = TextEditingController();
  final _notes = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _discValue = TextEditingController();
  final _couponCtrl = TextEditingController();
  final _paid = TextEditingController();
  final _custFocus = FocusNode();
  bool _credit = false;

  DateTime _date = DateTime.now();
  final List<InvoiceItem> _items = [];
  int? _selectedProductId;

  String _discType = 'none';
  String? _couponCode;

  /// أصناف عدّل المستخدم هديّتها يدوياً (لا تُعاد حسابها تلقائياً).
  final Set<String> _manualGift = {};

  static const _mine = 'mine', _company = 'company';
  static const _purple = Color(0xFF8B5CF6), _blue = Color(0xFF2563EB);
  String _key(int productId, String type) => '$productId:$type';

  /// الكميات الباقية في الفاتورة المحفوظة (تُحسب متاحة عند التعديل).
  final Map<int, int> _oldKept = {};

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _customer.text = e.customerName;
      _number.text = e.number;
      _notes.text = e.notes;
      _date = e.date;
      _discType = e.discountType;
      _couponCode = e.couponCode;
      if (e.discountType != 'none') _discValue.text = _plain(e.discountValue);
      if (e.paidAmount != null) {
        _credit = true;
        _paid.text = _plain(e.paidAmount!);
      }
      for (final it in e.items) {
        _items.add(InvoiceItem(
          id: it.id,
          productId: it.productId,
          productName: it.productName,
          quantity: it.quantity,
          buyPrice: it.buyPrice,
          sellPrice: it.sellPrice,
          discountType: it.discountType,
          discountValue: it.discountValue,
          isGift: it.isGift,
          giftType: it.giftType,
          returnedQty: it.returnedQty,
        ));
        _oldKept[it.productId] = (_oldKept[it.productId] ?? 0) + it.keptQty;
        if (it.isGift) _manualGift.add(_key(it.productId, it.giftType));
      }
    } else {
      context.read<InvoiceProvider>().nextNumber().then((n) {
        if (mounted && _number.text.isEmpty) _number.text = n;
      });
      final r = widget.fromReservation;
      if (r != null) {
        _customer.text = r.customerName;
        _notes.text = r.notes;
        final products = context.read<ProductProvider>();
        for (final it in r.items) {
          final prod = products.byId(it.productId);
          if (prod != null) _addProduct(prod, it.quantity, silent: true);
        }
      }
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _number.dispose();
    _notes.dispose();
    _qtyCtrl.dispose();
    _discValue.dispose();
    _couponCtrl.dispose();
    _paid.dispose();
    _custFocus.dispose();
    super.dispose();
  }

  String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  Invoice _draft() => Invoice(
        id: widget.editing?.id,
        number: _number.text.trim(),
        customerName: _customer.text.trim(),
        date: _date,
        notes: _notes.text.trim(),
        items: _items,
        discountType: _discType,
        discountValue: _discType == 'none' ? 0 : (Fmt.parseNum(_discValue.text) ?? 0),
        couponCode: _discType == 'none' ? null : _couponCode,
        customerId: widget.editing?.customerId,
        paidAmount: _credit ? (Fmt.parseNum(_paid.text) ?? 0) : null,
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t != null) {
      setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
    }
  }

  int _paidQty(int productId) => _items
      .where((i) => i.productId == productId && !i.isGift)
      .fold(0, (s, i) => s + i.keptQty);

  int _giftQty(int productId, String type) => _items
      .where((i) => i.productId == productId && i.isGift && i.giftType == type)
      .fold(0, (s, i) => s + i.keptQty);

  /// عدد الهدايا المطلوب لنوع عرض: ⌊المباع ÷ N⌋ × M، أو الحالي إن عُدِّل يدوياً.
  int _wantGifts(Product prod, String type, int paid) {
    final buy = type == _mine ? prod.offerBuyQty : prod.companyBuyQty;
    final free = type == _mine ? prod.offerFreeQty : prod.companyFreeQty;
    final has = type == _mine ? prod.hasOffer : prod.hasCompanyOffer;
    if (!has || _manualGift.contains(_key(prod.id!, type))) {
      return _giftQty(prod.id!, type);
    }
    return (paid ~/ buy) * free;
  }

  void _addItem() {
    if (_selectedProductId == null) return;
    final qty = (Fmt.parseNum(_qtyCtrl.text) ?? 0).toInt();
    if (qty <= 0) return;
    final prod = context.read<ProductProvider>().byId(_selectedProductId!);
    if (prod == null) return;
    if (_addProduct(prod, qty)) {
      setState(() {
        _qtyCtrl.text = '1';
        _selectedProductId = null;
      });
    }
  }

  /// يضيف صنفاً (مع هداياه التلقائية بنوعيها). يعيد false عند نقص المخزون.
  bool _addProduct(Product prod, int qty, {bool silent = false}) {
    final available = prod.quantity + (_oldKept[prod.id] ?? 0);
    final newPaid = _paidQty(prod.id!) + qty;
    final mine = _wantGifts(prod, _mine, newPaid);
    final co = _wantGifts(prod, _company, newPaid);
    if (newPaid + mine + co > available) {
      if (!silent) {
        _error('الكمية المتوفرة $available فقط (مع الهدايا ${newPaid + mine + co})');
      }
      return false;
    }
    _items.add(InvoiceItem(
      productId: prod.id!,
      productName: prod.name,
      quantity: qty,
      buyPrice: prod.buyPrice,
      sellPrice: prod.sellPrice,
    ));
    _syncGifts(prod, newPaid);
    return true;
  }

  void _syncGifts(Product prod, int paid) {
    if (prod.hasOffer && !_manualGift.contains(_key(prod.id!, _mine))) {
      _setGift(prod, _mine, _wantGifts(prod, _mine, paid));
    }
    if (prod.hasCompanyOffer && !_manualGift.contains(_key(prod.id!, _company))) {
      _setGift(prod, _company, _wantGifts(prod, _company, paid));
    }
  }

  /// يضبط سطر الهدية التلقائي لصنف ونوع (يُنشئه أو يعدّله أو يحذفه).
  void _setGift(Product prod, String type, int qty) {
    final idx = _items.indexWhere(
        (i) => i.productId == prod.id && i.isGift && i.giftType == type);
    if (qty <= 0) {
      if (idx >= 0) _items.removeAt(idx);
      return;
    }
    if (idx >= 0) {
      _items[idx].quantity = qty + _items[idx].returnedQty;
    } else {
      _items.add(InvoiceItem(
        productId: prod.id!,
        productName: prod.name,
        quantity: qty,
        buyPrice: prod.buyPrice,
        sellPrice: 0,
        isGift: true,
        giftType: type,
      ));
    }
  }

  void _removeItem(int idx) {
    final it = _items[idx];
    final prod = context.read<ProductProvider>().byId(it.productId);
    setState(() {
      _items.removeAt(idx);
      if (it.isGift) {
        _manualGift.add(_key(it.productId, it.giftType)); // حذف يدوي: لا تعاد تلقائياً
      } else if (prod != null) {
        _syncGifts(prod, _paidQty(prod.id!));
      }
    });
  }

  Future<void> _editGift(int idx) async {
    final it = _items[idx];
    final c = TextEditingController(text: '${it.keptQty}');
    Fmt.selectAll(c);
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('كمية الهدية (${it.giftType == _company ? 'الشركة' : 'حسابي'}): ${it.productName}'),
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
            onPressed: () => Navigator.pop(ctx, Fmt.parseNum(c.text)?.toInt()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (v == null || v < 0 || !mounted) return;
    final prod = context.read<ProductProvider>().byId(it.productId);
    final available = (prod?.quantity ?? 0) + (_oldKept[it.productId] ?? 0);
    final otherGifts = _items
        .where((i) => i.productId == it.productId && i.isGift && !identical(i, it))
        .fold<int>(0, (s, i) => s + i.keptQty);
    if (_paidQty(it.productId) + otherGifts + v > available) {
      _error('الكمية المتوفرة $available فقط');
      return;
    }
    setState(() {
      _manualGift.add(_key(it.productId, it.giftType));
      if (v == 0) {
        _items.removeAt(idx);
      } else {
        it.quantity = v + it.returnedQty;
      }
    });
  }

  Future<void> _editItemDiscount(int idx) async {
    final it = _items[idx];
    var type = it.discountType == 'none' ? 'percent' : it.discountType;
    final c = TextEditingController(text: it.discountType == 'none' ? '' : _plain(it.discountValue));
    Fmt.selectAll(c);
    final res = await showDialog<_Disc>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('خصم على: ${it.productName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'percent', label: Text('نسبة %')),
                  ButtonSegment(value: 'amount', label: Text('مبلغ')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setD(() => type = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                onTap: () => Fmt.selectAll(c),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: type == 'percent' ? 'نسبة الخصم %' : 'مبلغ الخصم',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, const _Disc('none', 0)),
              child: const Text('إزالة الخصم'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            TextButton(
              onPressed: () {
                final v = Fmt.parseNum(c.text) ?? 0;
                Navigator.pop(ctx, v > 0 ? _Disc(type, v) : const _Disc('none', 0));
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      it.discountType = res.type;
      it.discountValue = res.value;
    });
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    final c = await CouponRepository().findByCode(code);
    if (!mounted) return;
    if (c == null || !c.active) {
      _error('الكوبون غير موجود أو معطّل');
      return;
    }
    if (c.isExpired) {
      _error('الكوبون منتهي الصلاحية');
      return;
    }
    setState(() {
      _discType = c.type;
      _discValue.text = _plain(c.value);
      _couponCode = c.code;
      _couponCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_customer.text.trim().isEmpty || _items.isEmpty) {
      _error('أدخل اسم الصيدلاني/ة وأضف صنفاً واحداً على الأقل');
      return;
    }
    final number = _number.text.trim();
    if (number.isEmpty) {
      _error('أدخل رقم الفاتورة');
      return;
    }
    final invProvider = context.read<InvoiceProvider>();
    final prodProvider = context.read<ProductProvider>();
    if (await invProvider.numberExists(number, exceptId: widget.editing?.id)) {
      _error('رقم الفاتورة مستخدم من قبل');
      return;
    }

    final inv = _draft();
    try {
      final parties = context.read<PartyProvider>();
      final name = _customer.text.trim();
      final c = parties.customerByName(name);
      if (c == null) {
        inv.customerId = await parties.addCustomer(Party(name: name));
      } else {
        inv.customerId = c.id;
      }
      final r = widget.fromReservation;
      if (r != null && !_isEdit) {
        await parties.setReservationStatus(r.id!, 'done');
      }
      if (_isEdit) {
        await invProvider.update(inv);
      } else {
        await invProvider.add(inv);
      }
      await prodProvider.loadProducts();
    } catch (e) {
      _error('تعذّر الحفظ: $e');
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final settings = context.watch<SettingsProvider>();
    final cur = settings.currency;
    final draft = _draft();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل الفاتورة' : 'فاتورة جديدة')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(settings.storeName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: settings.phone.isEmpty ? null : Text('هاتف: ${settings.phone}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RawAutocomplete<String>(
                    textEditingController: _customer,
                    focusNode: _custFocus,
                    optionsBuilder: (v) {
                      final q = v.text.trim();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return context
                          .read<PartyProvider>()
                          .customers
                          .map((c) => c.name)
                          .where((n) => n.contains(q) && n != q);
                    },
                    fieldViewBuilder: (ctx, c, f, _) => TextField(
                      controller: c,
                      focusNode: f,
                      decoration: const InputDecoration(
                        labelText: 'الصيدلاني/ة المحترم/ة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    optionsViewBuilder: (ctx, onSelected, options) => Align(
                      alignment: Alignment.topRight,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final o in options)
                                ListTile(title: Text(o), onTap: () => onSelected(o)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _number,
                  onTap: () => Fmt.selectAll(_number),
                    decoration: const InputDecoration(
                      labelText: 'رقم الفاتورة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'التاريخ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(Fmt.date(_date)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'الوقت',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(Fmt.time(_date)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedProductId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
                    items: products.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.quantity} متوفر)${p.hasOffer ? ' 🎁 كل ${p.offerBuyQty}+${p.offerFreeQty}' : ''}${p.hasCompanyOffer ? ' 🎁ش كل ${p.companyBuyQty}+${p.companyFreeQty}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          onTap: () => Fmt.selectAll(_qtyCtrl),
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
                    ..._items.asMap().entries.map((e) => _itemCard(e.key, e.value, cur)),
                  const SizedBox(height: 16),
                  _discountCard(cur),
                  const SizedBox(height: 12),
                  _creditCard(cur, draft),
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
                  if (draft.totalDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموع الكلي قبل الخصم'),
                        Text(Fmt.money(draft.grossTotal, cur)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الخصم${draft.couponCode != null ? ' (${draft.couponCode})' : ''}'),
                        Text('- ${Fmt.money(draft.totalDiscount, cur)}',
                            style: const TextStyle(color: AppColors.danger)),
                      ],
                    ),
                    const Divider(),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(draft.totalDiscount > 0 ? 'المجموع بعد الخصم:' : 'المجموع:',
                          style: const TextStyle(fontSize: 16)),
                      Text(Fmt.money(draft.total, cur),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(_isEdit ? 'حفظ التعديلات' : 'حفظ الفاتورة', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(int idx, InvoiceItem it, String cur) {
    final String discText;
    if (it.discountAmount > 0) {
      discText = it.discountType == 'percent'
          ? ' • خصم ${_plain(it.discountValue)}% = ${Fmt.money(it.discountAmount, cur)}'
          : ' • خصم ${Fmt.money(it.discountAmount, cur)}';
    } else {
      discText = '';
    }
    final giftColor = it.giftType == _company ? _blue : _purple;
    final giftLabel = it.giftType == _company ? 'الشركة' : 'حسابي';
    return Card(
      color: it.isGift ? giftColor.withValues(alpha: 0.08) : null,
      child: ListTile(
        title: Row(
          children: [
            Flexible(child: Text(it.productName)),
            if (it.isGift) ...[
              const SizedBox(width: 6),
              Icon(Icons.card_giftcard, size: 16, color: giftColor),
              Text(' هدية — $giftLabel',
                  style: TextStyle(color: giftColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        subtitle: Text(it.isGift
            ? '${it.keptQty} مجاناً ($giftLabel)'
            : '${it.quantity} × ${Fmt.money(it.sellPrice, cur)}$discText'
              '${it.returnedQty > 0 ? ' • مرتجع ${it.returnedQty}' : ''}',
            style: it.isGift ? TextStyle(color: giftColor) : null),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!it.isGift)
              Text(Fmt.money(it.totalSell, cur), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: it.isGift ? 'تعديل كمية الهدية' : 'خصم على الصنف',
              icon: Icon(it.isGift ? Icons.edit : Icons.percent, color: Theme.of(context).colorScheme.primary),
              onPressed: () => it.isGift ? _editGift(idx) : _editItemDiscount(idx),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.danger),
              onPressed: () => _removeItem(idx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creditCard(String cur, Invoice draft) {
    final paid = Fmt.parseNum(_paid.text) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('بيع بالآجل (دَين)'),
              value: _credit,
              onChanged: (v) => setState(() {
                _credit = v;
                if (v && _paid.text.isEmpty) _paid.text = '0';
              }),
            ),
            if (_credit) ...[
              TextField(
                controller: _paid,
                onTap: () => Fmt.selectAll(_paid),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع الآن ($cur)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المتبقي على الزبون: ${Fmt.money((draft.total - paid).clamp(0, double.infinity).toDouble(), cur)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _discountCard(String cur) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('خصم على الفاتورة كاملة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _discType,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('بدون خصم')),
                    DropdownMenuItem(value: 'percent', child: Text('نسبة %')),
                    DropdownMenuItem(value: 'amount', child: Text('مبلغ')),
                  ],
                  onChanged: (v) => setState(() {
                    _discType = v!;
                    _couponCode = null;
                    if (v == 'none') _discValue.clear();
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discValue,
                    enabled: _discType != 'none',
                    onTap: () => Fmt.selectAll(_discValue),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _couponCode = null),
                    decoration: InputDecoration(
                      labelText: _discType == 'percent' ? 'النسبة %' : 'المبلغ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رمز كوبون',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _applyCoupon, child: const Text('تطبيق')),
              ],
            ),
            if (_couponCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  label: Text('كوبون مُطبَّق: $_couponCode'),
                  onDeleted: () => setState(() {
                    _couponCode = null;
                    _discType = 'none';
                    _discValue.clear();
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Disc {
  final String type;
  final double value;
  const _Disc(this.type, this.value);
}
