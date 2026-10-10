import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/party.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/party_dialogs.dart';
import '../invoices/invoice_detail_screen.dart';
import 'customers_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final invProv = context.watch<InvoiceProvider>();
    final cur = context.watch<SettingsProvider>().currency;

    Party? c;
    for (final x in parties.customers) {
      if (x.id == customerId) c = x;
    }
    if (c == null) return const Scaffold(body: Center(child: Text('غير موجود')));
    final customer = c;

    final invoices = invProv.invoices.where((i) => i.customerId == customerId).toList();
    final bought = invoices.fold<double>(0, (s, i) => s + i.total);
    final owed = customerOwed(customerId, invProv, parties);
    final paid = bought - owed;
    final payments = parties.customerPayments.where((p) => p.partyId == customerId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final u = await showPartyDialog(context, initial: customer, title: 'تعديل الزبون');
              if (u != null && context.mounted) await context.read<PartyProvider>().updateCustomer(u);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف الزبون'),
                  content: const Text('تُحذف دفعاته وتبقى فواتيره. متابعة؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<PartyProvider>().deleteCustomer(customerId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await showAmountDialog(context, title: 'تسجيل دفعة', initial: owed);
          if (r != null && context.mounted) {
            await context.read<PartyProvider>().addCustomerPayment(PartyPayment(
                  partyId: customerId,
                  amount: r.amount,
                  date: DateTime.now(),
                  note: r.note,
                ));
          }
        },
        icon: const Icon(Icons.payments),
        label: const Text('تسجيل دفعة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (customer.phone.isNotEmpty) _row('الهاتف', customer.phone),
                  _row('إجمالي المشتريات', Fmt.money(bought, cur)),
                  _row('المدفوع', Fmt.money(paid, cur)),
                  const Divider(),
                  _row('المتبقي عليه', Fmt.money(owed, cur),
                      bold: true, color: owed > 0 ? AppColors.danger : AppColors.success),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('الفواتير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (invoices.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد فواتير')),
          for (final i in invoices)
            Card(
              child: ListTile(
                title: Text('فاتورة ${i.number} • ${Fmt.date(i.date)}'),
                subtitle: i.owed > 0
                    ? Text('متبقي ${Fmt.money(i.owed, cur)}', style: const TextStyle(color: AppColors.danger))
                    : null,
                trailing: Text(Fmt.money(i.total, cur), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: i.id!)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text('الدفعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (payments.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد دفعات')),
          for (final p in payments)
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: AppColors.success),
                title: Text(Fmt.money(p.amount, cur)),
                subtitle: Text('${Fmt.dateTime(p.date)}${p.note.isEmpty ? '' : ' • ${p.note}'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => context.read<PartyProvider>().deleteCustomerPayment(p.id!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.grey)),
        Text(value,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: bold ? 16 : 14)),
      ],
    ),
  );
}
