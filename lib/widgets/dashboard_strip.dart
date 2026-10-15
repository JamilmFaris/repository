import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/period.dart';
import '../core/utils/report_data.dart';
import '../providers/expense_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/party_provider.dart';
import '../providers/settings_provider.dart';

/// لوحة التحكم الذكية: أهم 4 أرقام في شريط صغير + زر تفاصيل.
class DashboardStrip extends StatelessWidget {
  const DashboardStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>().invoices;
    final exp = context.watch<ExpenseProvider>().expenses;
    final parties = context.watch<PartyProvider>();
    final s = context.watch<SettingsProvider>();
    final now = DateTime.now();

    final day = ReportData(
        range: PeriodRange.of(PeriodKind.day, now), allInvoices: inv, allExpenses: exp);
    final month = ReportData(
        range: PeriodRange.of(PeriodKind.month, now), allInvoices: inv, allExpenses: exp);
    final dues = _supplierDues(parties);
    final monthUsd = s.dollarRate > 0 ? month.netProfit / s.dollarRate : null;

    Widget cell(String label, String value, IconData icon, Color color) => Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(label,
                        style: const TextStyle(fontSize: 10, color: AppColors.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              ),
            ],
          ),
        );

    return Material(
      color: Theme.of(context).cardColor,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: [
            cell('ربحي اليوم', Fmt.num2(day.netProfit), Icons.today,
                day.netProfit >= 0 ? AppColors.success : AppColors.danger),
            cell('ربح الشهر \$', monthUsd == null ? '-' : Fmt.num2(double.parse(monthUsd.toStringAsFixed(1))),
                Icons.calendar_month, monthUsd == null || monthUsd >= 0 ? AppColors.success : AppColors.danger),
            cell('فواتير اليوم', '${day.invoices.length}', Icons.receipt_long,
                Theme.of(context).colorScheme.primary),
            cell('ديوني', Fmt.num2(dues), Icons.account_balance_wallet,
                dues > 0 ? AppColors.danger : AppColors.success),
            IconButton(
              tooltip: 'تفاصيل',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => _details(context, day, month, dues),
            ),
          ],
        ),
      ),
    );
  }

  static double _supplierDues(PartyProvider p) {
    var t = 0.0;
    for (final s in p.suppliers) {
      final b = p.supplierBalance(s.id!);
      if (b > 0) t += b;
    }
    return t;
  }

  void _details(BuildContext context, ReportData day, ReportData month, double dues) {
    final s = context.read<SettingsProvider>();
    final inv = context.read<InvoiceProvider>().invoices;
    final parties = context.read<PartyProvider>();
    final cur = s.currency;
    final custDebt = (inv.fold<double>(0, (a, i) => a + i.owed) -
            parties.customerPayments.fold<double>(0, (a, p) => a + p.amount))
        .clamp(0, double.infinity)
        .toDouble();

    Widget row(String k, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
              Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
            ],
          ),
        );

    List<Widget> block(String title, ReportData d) => [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          row('المبيعات', Fmt.money(d.sales, cur)),
          row('تكلفة البضاعة', Fmt.money(d.cost, cur)),
          row('الربح قبل المصاريف', Fmt.money(d.grossProfit, cur)),
          row('المصاريف', Fmt.money(d.expensesTotal, cur)),
          row('الربح الصافي',
              '${Fmt.money(d.netProfit, cur)}${s.dollarRate > 0 ? '  ≈ \$${Fmt.num2(double.parse((d.netProfit / s.dollarRate).toStringAsFixed(2)))}' : ''}',
              bold: true,
              color: d.netProfit >= 0 ? AppColors.success : AppColors.danger),
          row('عدد الفواتير', '${d.invoices.length}'),
        ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...block('اليوم', day),
              const Divider(height: 24),
              ...block('هذا الشهر', month),
              const Divider(height: 24),
              const Text('الذمم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              row('ديوني للموردين', Fmt.money(dues, cur),
                  color: dues > 0 ? AppColors.danger : AppColors.success),
              row('ديون الزبائن لي', Fmt.money(custDebt, cur)),
            ],
          ),
        ),
      ),
    );
  }
}
