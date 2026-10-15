import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cash_provider.dart';
import '../../providers/settings_provider.dart';
import 'cash_count_screen.dart';

/// 💰 الصندوق: رصيد الدرج النظري + حركات يدوية + جرد وسجل الجرد.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  Future<void> _manual(BuildContext context, String type) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final isIn = type == 'in';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'إدخال نقدي إلى الدرج' : 'سحب نقدي من الدرج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: () => Fmt.selectAll(amount),
              decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: 'السبب',
                hintText: isIn ? 'رأس مال، سيولة طارئة...' : 'مصاريف شخصية، طارئ...',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final v = Fmt.parseNum(amount.text) ?? 0;
    if (ok != true || v <= 0 || !context.mounted) return;
    await context.read<CashProvider>().addMovement(type, v, reason.text.trim());
  }

  Future<void> _opening(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الرصيد الافتتاحي للدرج'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'المبلغ الموجود الآن في الدرج',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final v = Fmt.parseNum(c.text);
    if (ok != true || v == null || v < 0 || !context.mounted) return;
    await context.read<CashProvider>().saveOpening(v);
  }

  @override
  Widget build(BuildContext context) {
    final cash = context.watch<CashProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final b = cash.breakdown;

    return Scaffold(
      appBar: AppBar(title: const Text('الصندوق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!cash.hasBaseline)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ابدأ بتسجيل رصيد الدرج الحالي',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                        'أدخل مرة واحدة المبلغ الموجود الآن في الدرج؛ بعدها يُحسب الرصيد النظري تلقائياً من المبيعات والتحصيلات والمصاريف.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _opening(context),
                      icon: const Icon(Icons.savings),
                      label: const Text('تسجيل الرصيد الافتتاحي'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              color: AppColors.success.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('الرصيد النظري الحالي للدرج',
                        style: TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 6),
                    Text(Fmt.money(cash.balance, cur),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.success)),
                    const SizedBox(height: 4),
                    Text('منذ آخر جرد: ${b.since == null ? '-' : Fmt.dateTime(b.since!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _manual(context, 'in'),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                    label: const Text('إدخال نقدي'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _manual(context, 'out'),
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                    label: const Text('سحب نقدي'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const CashCountScreen())),
                icon: const Icon(Icons.fact_check),
                label: const Text('جرد الصندوق', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('الحركات اليدوية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (cash.movements.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد حركات يدوية', style: TextStyle(color: AppColors.grey)),
            ),
          for (final m in cash.movements)
            Card(
              child: ListTile(
                leading: Icon(m.isIn ? Icons.south_west : Icons.north_east,
                    color: m.isIn ? AppColors.success : AppColors.danger),
                title: Text('${m.isIn ? '+' : '-'} ${Fmt.money(m.amount, cur)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${Fmt.dateTime(m.date)}${m.reason.isEmpty ? '' : ' • ${m.reason}'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => context.read<CashProvider>().deleteMovement(m.id),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text('سجل الجرد اليومي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (cash.counts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد عمليات جرد', style: TextStyle(color: AppColors.grey)),
            ),
          for (final c in cash.counts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.dateTime(c.date),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('النظري: ${Fmt.money(c.theoretical, cur)}'),
                    Text('الفعلي: ${Fmt.money(c.actual, cur)}'),
                    Text(
                      c.diff == 0
                          ? 'مطابق'
                          : (c.diff > 0
                              ? 'فائض ${Fmt.money(c.diff, cur)}'
                              : 'عجز ${Fmt.money(-c.diff, cur)}'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: c.diff == 0
                            ? AppColors.grey
                            : (c.diff > 0 ? AppColors.success : AppColors.danger),
                      ),
                    ),
                    if (c.note.isNotEmpty) Text('ملاحظة: ${c.note}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
