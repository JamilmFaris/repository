import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/party.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../providers/party_provider.dart';
import '../../providers/settings_provider.dart';
import 'receipt_view_screen.dart';

/// إصدار وصل استلام مبلغ من زبون. الحفظ يسجّل دفعة على حسابه فيُنقص دينه.
class ReceiptFormScreen extends StatefulWidget {
  final Party? customer;
  final double? suggestedAmount;
  const ReceiptFormScreen({super.key, this.customer, this.suggestedAmount});
  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  final _amount = TextEditingController();
  final _purpose = TextEditingController(text: 'سداد دَين');
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _name.text = widget.customer?.name ?? '';
    final a = widget.suggestedAmount;
    if (a != null && a > 0) {
      _amount.text = a == a.roundToDouble() ? '${a.toInt()}' : '$a';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    _amount.dispose();
    _purpose.dispose();
    _note.dispose();
    super.dispose();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = Fmt.parseNum(_amount.text) ?? 0;
    if (name.isEmpty) return _err('أدخل اسم السيد');
    if (amount <= 0) return _err('أدخل المبلغ المستلم');
    final parties = context.read<PartyProvider>();
    final nav = Navigator.of(context);
    final existing = parties.customerByName(name);
    final id = existing?.id ?? await parties.addCustomer(Party(name: name));
    final receipt = await ReceiptRepository().create(
      customerId: id,
      customerName: name,
      amount: amount,
      purpose: _purpose.text.trim(),
      note: _note.text.trim(),
      date: _date,
    );
    await parties.loadAll();
    nav.pushReplacement(
        MaterialPageRoute(builder: (_) => ReceiptViewScreen(receipt: receipt)));
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<SettingsProvider>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('وصل دفع جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RawAutocomplete<String>(
            textEditingController: _name,
            focusNode: _focus,
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
                labelText: 'اسم السيد',
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
                      for (final o in options) ListTile(title: Text(o), onTap: () => onSelected(o)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => Fmt.selectAll(_amount),
            decoration: InputDecoration(
              labelText: 'المبلغ المستلم ($cur)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purpose,
            onTap: () => Fmt.selectAll(_purpose),
            decoration: const InputDecoration(
              labelText: 'وذلك مقابل',
              hintText: 'سداد دَين، دفعة من فاتورة...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
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
                      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'التاريخ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event)),
                    child: Text(Fmt.date(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay.fromDateTime(_date));
                    if (t != null) {
                      setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'الوقت', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                    child: Text(Fmt.time(_date)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'ملاحظة إضافية (اختياري)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text('سيُسجَّل المبلغ كدفعة على حساب الزبون (يُنقص دَينه).',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.receipt),
              label: const Text('إصدار الوصل', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
