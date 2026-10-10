import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/reservation.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/empty_state.dart';
import '../invoices/create_invoice_screen.dart';

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final list = parties.reservations;

    return Scaffold(
      appBar: AppBar(title: const Text('الحجوزات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const _ReservationForm())),
        icon: const Icon(Icons.add),
        label: const Text('حجز جديد'),
      ),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.bookmark_border,
              title: 'لا توجد حجوزات',
              subtitle: 'سجّل طلباً مسبقاً لتذكّره وحوّله لفاتورة عند الاستلام')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _card(ctx, list[i]),
            ),
    );
  }

  Widget _card(BuildContext context, Reservation r) {
    final open = r.status == 'open';
    final label = switch (r.status) {
      'done' => 'تم التسليم',
      'cancelled' => 'ملغى',
      _ => 'مفتوح',
    };
    final color = switch (r.status) {
      'done' => AppColors.success,
      'cancelled' => AppColors.grey,
      _ => AppColors.warning,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(
                  label: Text(label, style: TextStyle(color: color, fontSize: 12)),
                  side: BorderSide(color: color),
                ),
              ],
            ),
            Text('${Fmt.date(r.date)}${r.dueDate == null ? '' : ' • موعد الاستلام ${Fmt.date(r.dueDate!)}'}',
                style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            for (final it in r.items) Text('• ${it.productName} × ${it.quantity}'),
            if (r.notes.isNotEmpty) Text('ملاحظة: ${r.notes}'),
            const SizedBox(height: 8),
            Row(
              children: [
                if (open)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('تحويل لفاتورة'),
                    onPressed: () async {
                      final res = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => CreateInvoiceScreen(fromReservation: r)),
                      );
                      if (res == true && context.mounted) {
                        await context.read<ProductProvider>().loadProducts();
                        await context.read<InvoiceProvider>().loadInvoices();
                      }
                    },
                  ),
                const Spacer(),
                if (open)
                  TextButton(
                    onPressed: () =>
                        context.read<PartyProvider>().setReservationStatus(r.id!, 'cancelled'),
                    child: const Text('إلغاء الحجز'),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => context.read<PartyProvider>().deleteReservation(r.id!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationForm extends StatefulWidget {
  const _ReservationForm();
  @override
  State<_ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<_ReservationForm> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _qty = TextEditingController(text: '1');
  DateTime? _due;
  int? _productId;
  final List<ReservationItem> _items = [];

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    return Scaffold(
      appBar: AppBar(title: const Text('حجز جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'اسم الزبون', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _due ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _due = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'موعد الاستلام (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event)),
              child: Text(_due == null ? '—' : Fmt.date(_due!)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'ملاحظة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _productId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الصنف', border: OutlineInputBorder()),
            items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (v) => setState(() => _productId = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: () {
                  final prod = _productId == null
                      ? null
                      : context.read<ProductProvider>().byId(_productId!);
                  final q = (Fmt.parseNum(_qty.text) ?? 0).toInt();
                  if (prod == null || q <= 0) return;
                  setState(() {
                    _items.add(ReservationItem(
                        productId: prod.id!, productName: prod.name, quantity: q));
                    _productId = null;
                    _qty.text = '1';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++)
            ListTile(
              title: Text(_items[i].productName),
              subtitle: Text('الكمية ${_items[i].quantity}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.danger),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ الحجز'),
              onPressed: () async {
                if (_name.text.trim().isEmpty || _items.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('أدخل اسم الزبون وصنفاً واحداً على الأقل')));
                  return;
                }
                await context.read<PartyProvider>().addReservation(Reservation(
                      customerName: _name.text.trim(),
                      date: DateTime.now(),
                      dueDate: _due,
                      notes: _notes.text.trim(),
                      items: _items,
                    ));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
