import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/receipt.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../providers/party_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'receipt_form_screen.dart';
import 'receipt_view_screen.dart';

/// سجل الوصولات المحفوظة مع بحث بالاسم أو الرقم.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _repo = ReceiptRepository();
  List<Receipt> _all = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await _repo.all();
    if (mounted) setState(() => _all = l);
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<SettingsProvider>().currency;
    final q = _q.trim();
    final list = _all
        .where((r) => q.isEmpty || r.customerName.contains(q) || '${r.number}' == q)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الوصولات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ReceiptFormScreen()));
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('وصل جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الزبون أو رقم الوصل...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'لا توجد وصولات',
                    subtitle: 'أصدر وصلاً عند استلام دفعة من زبون')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${r.number}')),
                          title: Text(r.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${Fmt.dateTime(r.date)}${r.purpose.isEmpty ? '' : ' • ${r.purpose}'}'),
                          trailing: Text(Fmt.money(r.amount, cur),
                              style: const TextStyle(
                                  color: AppColors.success, fontWeight: FontWeight.bold)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReceiptViewScreen(receipt: r)),
                          ),
                          onLongPress: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف الوصل'),
                                content: const Text(
                                    'سيُحذف الوصل وتُلغى الدفعة المرتبطة به (يعود الدَّين). متابعة؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('حذف',
                                        style: TextStyle(color: AppColors.danger)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final parties = context.read<PartyProvider>();
                              await _repo.delete(r);
                              await parties.loadAll();
                              await _load();
                            }
                          },
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
