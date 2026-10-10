import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/party_dialogs.dart';
import 'customer_detail_screen.dart';

/// المتبقي على زبون = ديون فواتيره − دفعاته.
double customerOwed(int customerId, InvoiceProvider inv, PartyProvider parties) {
  final debt = inv.invoices
      .where((i) => i.customerId == customerId)
      .fold<double>(0, (s, i) => s + i.owed);
  return debt - parties.paidByCustomer(customerId);
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final inv = context.watch<InvoiceProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = parties.customers.where((c) => c.name.contains(_q.trim())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final c = await showPartyDialog(context, title: 'زبون جديد');
          if (c != null && context.mounted) await context.read<PartyProvider>().addCustomer(c);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('زبون جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن زبون...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'لا يوجد زبائن',
                    subtitle: 'يُضاف الزبون تلقائياً عند أول فاتورة، أو من الزر أدناه')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final owed = customerOwed(c.id!, inv, parties);
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: c.phone.isEmpty ? null : Text(c.phone),
                          trailing: Text(
                            owed > 0 ? 'عليه ${Fmt.money(owed, cur)}' : 'لا دَين',
                            style: TextStyle(
                              color: owed > 0 ? AppColors.danger : AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id!)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
