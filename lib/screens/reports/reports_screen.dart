import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../core/utils/report_data.dart';
import '../../core/utils/report_pdf.dart';
import '../../providers/expense_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/period_selector.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  PeriodRange _range = PeriodRange.of(PeriodKind.month, DateTime.now());

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>();
    final prod = context.watch<ProductProvider>();
    final exp = context.watch<ExpenseProvider>();
    final parties = context.watch<PartyProvider>();
    final settings = context.watch<SettingsProvider>();
    final cur = settings.currency;

    final data = ReportData(range: _range, allInvoices: inv.invoices, allExpenses: exp.expenses);

    final stockBuy = prod.products.fold<double>(0, (s, p) => s + p.buyPrice * p.quantity);
    final stockSell = prod.products.fold<double>(0, (s, p) => s + p.sellPrice * p.quantity);
    final customersOwed = inv.invoices.fold<double>(0, (s, i) => s + i.owed) -
        parties.customerPayments.fold<double>(0, (s, p) => s + p.amount);
    final suppliersOwed =
        parties.suppliers.fold<double>(0, (s, x) => s + parties.supplierBalance(x.id!));
    final capital = CapitalSummary(
      stockBuy: stockBuy,
      stockSell: stockSell,
      customersOwed: customersOwed < 0 ? 0 : customersOwed,
      suppliersOwed: suppliersOwed < 0 ? 0 : suppliersOwed,
    );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            tooltip: 'تصدير PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final bytes = await ReportPdf.build(
                data: data,
                capital: capital,
                storeName: settings.storeName,
                currency: cur,
              );
              await ReportPdf.share(bytes, _range.label.replaceAll('/', '-'));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24, top: 8),
        children: [
          PeriodSelector(onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 8),
          _netBox(data, cur),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _statCard('إجمالي المبيعات', Fmt.money(data.sales, cur), Icons.attach_money, _palette[0]),
                _statCard('تكلفة البضاعة', Fmt.money(data.cost, cur), Icons.shopping_cart, AppColors.warning),
                _statCard('الربح قبل المصاريف', Fmt.money(data.grossProfit, cur), Icons.trending_up, AppColors.success),
                _statCard('إجمالي المصاريف', Fmt.money(data.expensesTotal, cur), Icons.payments, AppColors.danger),
                _statCard('الخصومات الممنوحة', Fmt.money(data.discountsTotal, cur), Icons.percent, _palette[4]),
                _statCard('عدد الفواتير', '${data.invoices.length}', Icons.receipt, _palette[5]),
              ],
            ),
          ),
          _capitalCard(capital, cur),
          _chartCard('المبيعات والأرباح', _lineChart(data.series)),
          if (data.expensesByCategory.isNotEmpty)
            _chartCard('توزيع المصاريف', _expensesPie(data), height: 200),
          _listCard(
            'الأصناف الأكثر ربحاً',
            [for (final p in data.topByProfit()) MapEntry('${p.name} (${p.qty})', Fmt.money(p.profit, cur))],
          ),
          _listCard(
            'الأصناف الأكثر مبيعاً',
            [for (final p in data.topByQty()) MapEntry(p.name, '${p.qty} قطعة')],
          ),
          if (data.topByProfit().isNotEmpty)
            _chartCard('ربح كل صنف', _barChart([
              for (final p in data.topByProfit(6)) MapEntry(p.name, p.profit),
            ], _palette[1])),
          _listCard(
            'أفضل الزبائن',
            [for (final c in data.topCustomers()) MapEntry(c.key, Fmt.money(c.value, cur))],
          ),
        ],
      ),
    );
  }

  /// صندوق: ربحت X — خُصم منها ... = الصافي Y
  Widget _netBox(ReportData d, String cur) {
    final cats = d.expensesByCategory;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: d.netProfit >= 0
          ? AppColors.success.withValues(alpha: 0.12)
          : AppColors.danger.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ربحت ${Fmt.money(d.grossProfit, cur)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (cats.isEmpty)
              const Text('لا توجد مصاريف في هذه الفترة', style: TextStyle(color: AppColors.grey))
            else ...[
              const Text('خُصم منها:', style: TextStyle(color: AppColors.grey)),
              for (final c in cats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${c.key}  (${d.percentOfExpenses(c.value).toStringAsFixed(0)}%)'),
                      Text('- ${Fmt.money(c.value, cur)}',
                          style: const TextStyle(color: AppColors.danger)),
                    ],
                  ),
                ),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('= الربح الصافي النهائي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(Fmt.money(d.netProfit, cur),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: d.netProfit >= 0 ? AppColors.success : AppColors.danger,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _capitalCard(CapitalSummary c, String cur) {
    Widget row(String k, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
              Text(Fmt.money(v, cur),
                  style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 16 : 14)),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('رأس المال والمخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            row('البضاعة كاملة بسعر الشراء', c.stockBuy),
            row('البضاعة كاملة بسعر البيع', c.stockSell),
            row('الربح المتوقع من المخزون', c.expectedProfit),
            row('ديون الزبائن (نقدية متوقعة)', c.customersOwed),
            row('مستحقات الموردين', c.suppliersOwed),
            const Divider(),
            row('رأس المال الحالي', c.capital, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 12, color: AppColors.grey),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    ),
  );

  Widget _listCard(String title, List<MapEntry<String, String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${i + 1}.')),
                    Expanded(child: Text(rows[i].key, overflow: TextOverflow.ellipsis)),
                    Text(rows[i].value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, Widget chart, {double height = 220}) => Card(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(height: height, child: chart),
        ],
      ),
    ),
  );

  Widget _lineChart(List<SeriesPoint> s) {
    if (s.isEmpty) return const Center(child: Text('لا توجد بيانات'));
    LineChartBarData line(List<double> ys, Color c) => LineChartBarData(
          spots: [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])],
          isCurved: true,
          color: c,
          barWidth: 3,
          dotData: const FlDotData(show: false),
        );
    return LineChart(LineChartData(
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: (s.length / 5).ceilToDouble().clamp(1, 1000),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= s.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s[i].label, style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        line([for (final p in s) p.sales], _palette[0]),
        line([for (final p in s) p.profit], _palette[1]),
      ],
    ));
  }

  Widget _barChart(List<MapEntry<String, double>> items, Color color) {
    return BarChart(BarChartData(
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= items.length) return const SizedBox();
              final n = items[i].key;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(n.length > 8 ? '${n.substring(0, 8)}…' : n,
                    style: const TextStyle(fontSize: 9)),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < items.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
                toY: items[i].value < 0 ? 0 : items[i].value,
                color: color,
                width: 16,
                borderRadius: BorderRadius.circular(4)),
          ]),
      ],
    ));
  }

  Widget _expensesPie(ReportData d) {
    final cats = d.expensesByCategory;
    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: [
              for (var i = 0; i < cats.length; i++)
                PieChartSectionData(
                  value: cats[i].value,
                  color: _palette[i % _palette.length],
                  radius: 50,
                  title: '${d.percentOfExpenses(cats[i].value).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
            ],
          )),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cats.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10, color: _palette[i % _palette.length]),
                  const SizedBox(width: 6),
                  Text(cats[i].key, style: const TextStyle(fontSize: 12)),
                ]),
              ),
          ],
        ),
      ],
    );
  }
}
