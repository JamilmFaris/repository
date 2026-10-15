import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/party_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/motion.dart';
import '../../widgets/party_dialogs.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<PartyProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = parties.suppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('الموردون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final s = await showPartyDialog(context, title: 'مورّد جديد');
          if (s != null && context.mounted) await context.read<PartyProvider>().addSupplier(s);
        },
        icon: const Icon(Icons.add),
        label: const Text('مورّد جديد'),
      ),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'لا يوجد موردون',
              subtitle: 'أضف مورّدك الأول من الزر أدناه')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                final bal = parties.supplierBalance(s.id!);
                return FadeSlideIn(
                  index: i,
                  child: StatusCard(
                    statusColor: bal > 0 ? AppColors.danger : AppColors.success,
                    child: ListTile(
                      leading: PartyAvatar(name: s.name),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: s.phone.isEmpty ? null : Text(s.phone),
                      trailing: Text(
                        bal > 0
                            ? 'له ${Fmt.money(bal, cur)}'
                            : (bal < 0 ? 'لك ${Fmt.money(-bal, cur)}' : 'لا مستحقات'),
                        style: TextStyle(
                          color: bal > 0 ? AppColors.danger : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplierId: s.id!)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
