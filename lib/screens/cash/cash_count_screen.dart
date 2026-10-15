import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cash_provider.dart';
import '../../providers/settings_provider.dart';

/// جرد الصندوق: المعادلة النظرية + المبلغ الفعلي + الفرق (فائض/عجز).
class CashCountScreen extends StatefulWidget {
  const CashCountScreen({super.key});
  @override
  State<CashCountScreen> createState() => _CashCountScreenState();
}

class _CashCountScreenState extends State<CashCountScreen> {
  final _actual = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<CashProvider>().breakdown;
    final cur = context.watch<SettingsProvider>().currency;
    final actual = Fmt.parseNum(_actual.text);
    final diff = actual == null ? null : actual - b.theoretical;

    Widget line(String label, double v, {bool minus = false, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${minus ? '−' : '+'} $label',
                  style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
              Text(Fmt.money(v, cur),
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : null,
                      color: minus ? AppColors.danger : null)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('جرد الصندوق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'منذ آخر جرد: ${b.since == null ? '-' : Fmt.dateTime(b.since!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('النقد الافتتاحي'),
                      Text(Fmt.money(b.baseline, cur)),
                    ],
                  ),
                  line('المبيعات النقدية', b.cashSales),
                  line('تحصيلات ديون الزبائن', b.collections),
                  line('إدخالات نقدية يدوية', b.manualIn),
                  line('دفعات الموردين', b.supplierPayments, minus: true),
                  line('المصاريف المسددة نقداً', b.expenses, minus: true),
                  line('الشحن والجمارك', b.shipping, minus: true),
                  line('مرتجعات الزبائن النقدية', b.refunds, minus: true),
                  line('المسحوبات اليدوية', b.manualOut, minus: true),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('= الرصيد النظري للدرج',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(Fmt.money(b.theoretical, cur),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _actual,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'المبلغ الفعلي في الدرج ($cur)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payments),
            ),
          ),
          if (diff != null) ...[
            const SizedBox(height: 12),
            Card(
              color: (diff == 0
                      ? AppColors.grey
                      : (diff > 0 ? AppColors.success : AppColors.danger))
                  .withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  diff == 0
                      ? 'الدرج مطابق للرصيد النظري'
                      : (diff > 0
                          ? 'فائض: ${Fmt.money(diff, cur)}'
                          : 'عجز: ${Fmt.money(-diff, cur)}'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: diff == 0
                        ? AppColors.grey
                        : (diff > 0 ? AppColors.success : AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: actual == null
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      await context.read<CashProvider>().saveCount(actual, _note.text.trim());
                      nav.pop();
                    },
              icon: const Icon(Icons.save),
              label: const Text('حفظ الجرد', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
