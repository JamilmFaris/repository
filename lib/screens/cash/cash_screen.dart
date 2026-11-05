import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/cash_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/cash_service.dart';
import 'cash_count_screen.dart';

/// 💰 الصندوق: رصيد الدرج النظري + حركات يدوية + جرد وسجل الجرد.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  static const _autoLimit = 30;

  String _usd(double syp, double rate) =>
      '\$${Fmt.num2(double.parse((syp / rate).toStringAsFixed(2)))}';

  /// الدولار المعروض للرصيد الافتتاحي: المُدخل أصلاً بالدولار، وإلا محوَّل بالسعر الحالي.
  String _openingUsd(CashCount o, double rate) {
    if (o.enteredInUsd) return '\$${Fmt.num2(o.usdAmount)}';
    return rate > 0 ? '≈ ${_usd(o.actual, rate)}' : 'حدّد سعر الدولار';
  }

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

  /// سعر الدولار المعتمد لتحويل الرصيد (سعر الشراء، وإلا سعر البيع).
  double _rate(SettingsProvider s) => s.dollarBuyRate > 0 ? s.dollarBuyRate : s.dollarRate;

  /// إدخال/تعديل الرصيد الافتتاحي بالليرة أو بالدولار (يُحوَّل ويُعرض بالعملتين).
  Future<void> _opening(BuildContext context, {CashCount? existing}) async {
    final settings = context.read<SettingsProvider>();
    final cash = context.read<CashProvider>();
    final cur = settings.currency;
    final rate = _rate(settings);
    var usd = existing?.enteredInUsd ?? false;
    final c = TextEditingController(
        text: existing == null
            ? ''
            : Fmt.num2(usd ? existing.usdAmount : existing.actual).replaceAll(',', ''));
    final hasLater = existing != null && cash.counts.any((x) => x.id != existing.id);
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final v = Fmt.parseNum(c.text);
          final preview = v == null || rate <= 0
              ? null
              : (usd ? '≈ ${Fmt.money(v * rate, cur)}' : '≈ ${_usd(v, rate)}');
          return AlertDialog(
            title: Text(existing == null ? 'الرصيد الافتتاحي للدرج' : 'تعديل الرصيد الافتتاحي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(cur)),
                      const ButtonSegment(value: true, label: Text('دولار \$')),
                    ],
                    selected: {usd},
                    onSelectionChanged: (x) => setD(() {
                      usd = x.first;
                      error = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onTap: () => Fmt.selectAll(c),
                    onChanged: (_) => setD(() => error = null),
                    decoration: InputDecoration(
                      labelText: usd ? 'المبلغ بالدولار' : 'المبلغ الموجود الآن في الدرج',
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 8),
                    Text(preview, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  if (rate > 0)
                    Text('سعر الصرف: ${Fmt.num2(rate)} $cur',
                        style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  if (hasLater)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'ملاحظة: يوجد جرد أحدث من هذا الرصيد، والرصيد الحالي محسوب منه؛ لذا لن يتغيّر الرصيد الحالي.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              TextButton(
                onPressed: () {
                  final n = Fmt.parseNum(c.text);
                  if (n == null || n < 0) {
                    setD(() => error = 'أدخل مبلغاً صحيحاً');
                  } else if (usd && rate <= 0) {
                    setD(() => error = 'حدّد سعر الدولار من الإعدادات أولاً');
                  } else {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    final v = Fmt.parseNum(c.text);
    if (ok != true || v == null || v < 0 || !context.mounted) return;
    final syp = usd ? v * rate : v;
    final usdV = usd ? v : 0.0;
    final r = usd ? rate : 0.0;
    if (existing == null) {
      await cash.saveOpening(syp, usd: usdV, rate: r);
    } else {
      await cash.updateOpening(existing.id, syp, usd: usdV, rate: r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash = context.watch<CashProvider>();
    final cur = context.watch<SettingsProvider>().currency;
    final b = cash.breakdown;
    final rate = _rate(context.watch<SettingsProvider>());
    final opening = cash.opening;

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
                    if (rate > 0)
                      Text('≈ ${_usd(cash.balance, rate)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.grey)),
                    const SizedBox(height: 4),
                    Text('منذ آخر جرد: ${b.since == null ? '-' : Fmt.dateTime(b.since!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                  ],
                ),
              ),
            ),
            if (opening != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.savings, color: AppColors.primary),
                  title: const Text('الرصيد الافتتاحي'),
                  subtitle: Text(
                      '${Fmt.money(opening.actual, cur)}  •  ${_openingUsd(opening, rate)}\n${Fmt.dateTime(opening.date)}'),
                  isThreeLine: true,
                  trailing: TextButton.icon(
                    onPressed: () => _opening(context, existing: opening),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                  ),
                ),
              ),
            ],
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
          if (cash.hasBaseline) ...[
            const SizedBox(height: 20),
            const Text('الحركات التلقائية منذ آخر جرد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('الفواتير (المبلغ المدفوع فقط) والدفعات والمصاريف تُسجَّل هنا تلقائياً',
                style: TextStyle(fontSize: 12, color: AppColors.grey)),
            if (cash.autoEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا توجد حركات بعد', style: TextStyle(color: AppColors.grey)),
              ),
            for (final e in cash.autoEntries.take(_autoLimit))
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(e.isIn ? Icons.south_west : Icons.north_east,
                      color: e.isIn ? AppColors.success : AppColors.danger),
                  title: Text('${e.isIn ? '+' : '-'} ${Fmt.money(e.amount, cur)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${Fmt.dateTime(e.date)} • ${e.label}'),
                ),
              ),
            if (cash.autoEntries.length > _autoLimit)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('و ${cash.autoEntries.length - _autoLimit} حركة أقدم...',
                    style: const TextStyle(color: AppColors.grey)),
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
