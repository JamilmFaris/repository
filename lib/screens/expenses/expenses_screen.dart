import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/period_selector.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  PeriodRange _range = PeriodRange.of(PeriodKind.month, DateTime.now());

  Future<void> _edit([Expense? e]) async {
    final amount = TextEditingController(text: e == null ? '' : _plain(e.amount));
    final desc = TextEditingController(text: e?.description ?? '');
    var category = e?.category ?? Expense.manualCategories.first;
    var date = e?.date ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(e == null ? 'مصروف جديد' : 'تعديل مصروف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                  items: [
                    for (final c in Expense.manualCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setD(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onTap: () => Fmt.selectAll(amount),
                  decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(Fmt.date(date)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setD(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final v = Fmt.parseNum(amount.text) ?? 0;
    if (ok != true || v <= 0 || !mounted) return;
    final exp = Expense(
      id: e?.id,
      category: category,
      amount: v,
      description: desc.text.trim(),
      date: date,
    );
    final prov = context.read<ExpenseProvider>();
    if (e == null) {
      await prov.add(exp);
    } else {
      await prov.update(exp);
    }
  }

  String _plain(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ExpenseProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final list = prov.inRange(_range.start, _range.end);
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    for (final e in list) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90, top: 8),
        children: [
          PeriodSelector(onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي المصاريف', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(Fmt.money(total, cur),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.danger)),
                    ],
                  ),
                  if (cats.isNotEmpty) const Divider(),
                  for (final c in cats) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.key),
                        Text('${Fmt.money(c.value, cur)} (${(total == 0 ? 0 : c.value / total * 100).toStringAsFixed(0)}%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: total == 0 ? 0 : c.value / total),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                  icon: Icons.receipt_outlined,
                  title: 'لا توجد مصاريف',
                  subtitle: 'سجّل مصاريفك لتعرف أين تذهب أموالك'),
            ),
          for (final e in list)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(e.isAuto ? Icons.card_giftcard : Icons.payments_outlined,
                    color: e.isAuto ? AppColors.success : AppColors.warning),
                title: Text('${e.category} — ${Fmt.money(e.amount, cur)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${Fmt.date(e.date)}${e.description.isEmpty ? '' : ' • ${e.description}'}'
                    '${e.isAuto ? ' • تلقائي من الفاتورة' : ''}'),
                onTap: e.isAuto ? null : () => _edit(e),
                trailing: e.isAuto
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => context.read<ExpenseProvider>().delete(e.id!),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
