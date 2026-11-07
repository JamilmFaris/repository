import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/capital.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/period.dart';
import '../../core/utils/report_data.dart';
import '../../core/utils/report_pdf.dart';
import '../../providers/cash_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/movement_card.dart';
import '../../widgets/period_selector.dart';
import 'analytics_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  PeriodRange _range = PeriodRange.of(PeriodKind.month, DateTime.now());
  List<CapitalSnapshot> _snaps = [];

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final l = await CapitalSnapshots.all();
    if (mounted) setState(() => _snaps = l);
  }

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

    final data = ReportData(
      range: _range,
      allInvoices: inv.invoices,
      allExpenses: exp.expenses,
      allPurchases: parties.purchases,
    );

    final capital = CapitalSummary.compute(
      products: prod.products,
      invoices: inv.invoices,
      parties: parties,
      cash: context.watch<CashProvider>().balance,
    );
    final sell = settings.dollarRate;

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
                capitalRate: settings.dollarBuyRate > 0 ? settings.dollarBuyRate : settings.dollarRate,
                profitRate: settings.dollarRate,
              );
              await ReportPdf.share(bytes, _range.label.replaceAll('/', '-'));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24, top: 8),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ListTile(
              leading: const Icon(Icons.insights, color: AppColors.primary),
              title: const Text('التحليلات الذكية', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('حركة الأصناف • مقارنة المبيعات • توقّع احتياج المخزون'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
            ),
          ),
          _itemsCard(prod.products, settings.lowStock),
          PeriodSelector(onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 8),
          _netBox(data, cur, sell),
          _giftsBox(data, cur),
          _performanceBox(data, settings, cur),
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
                _statCard('الربح قبل المصاريف', '${Fmt.money(data.grossProfit, cur)}${_usd(data.grossProfit, sell)}', Icons.trending_up, AppColors.success),
                _statCard('إجمالي المصاريف', Fmt.money(data.expensesTotal, cur), Icons.payments, AppColors.danger),
                _statCard('الخصومات الممنوحة', Fmt.money(data.discountsTotal, cur), Icons.percent, _palette[4]),
                _statCard('عدد الفواتير', '${data.invoices.length}', Icons.receipt, _palette[5]),
                _statCard('شحن وجمارك الشراء', Fmt.money(data.shippingTotal, cur), Icons.local_shipping, _palette[7]),
              ],
            ),
          ),
          _capitalCard(capital, cur, settings.dollarBuyRate > 0 ? settings.dollarBuyRate : settings.dollarRate),
          _chartCard('المبيعات والأرباح', _lineChart(data.series)),
          if (data.expensesByCategory.isNotEmpty)
            _chartCard('توزيع المصاريف', _expensesPie(data), height: 200),
          _listCard(
            'الأصناف الأكثر ربحاً',
            [for (final p in data.topByProfit()) MapEntry('${p.name} (${p.qty})', '${Fmt.money(p.profit, cur)}${_usd(p.profit, sell)}')],
          ),
          _listCard(
            'الأصناف الأكثر مبيعاً',
            [for (final p in data.topByQty()) MapEntry(p.name, '${p.qty} قطعة')],
          ),
          if (data.topByProfit().isNotEmpty)
            _chartCard('ربح كل صنف', _barChart([
              for (final p in data.topByProfit(6)) MapEntry(p.name, p.profit),
            ], _palette[1])),
          _capitalHistory(settings),
          const MovementCard(),
          _listCard(
            'أفضل الزبائن',
            [for (final c in data.topCustomers()) MapEntry(c.key, Fmt.money(c.value, cur))],
          ),
        ],
      ),
    );
  }

  /// صندوق: ربحت X — خُصم منها ... = الصافي Y
  /// ما يعادل المبلغ بالدولار بسعر بيع الدولار (المرجع الثابت للربح).
  String _usd(double v, double sellRate) =>
      sellRate > 0 ? ' ≈ \$${Fmt.num2(double.parse((v / sellRate).toStringAsFixed(2)))}' : '';

  /// 📦 عدد الأصناف: الإجمالي + النافدة + التي وصلت للحد الأدنى.
  Widget _itemsCard(List products, int low) {
    final total = products.length;
    final out = products.where((p) => p.quantity <= 0).length;
    final atMin = products.where((p) => p.quantity > 0 && p.quantity <= low).length;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.inventory_2, color: AppColors.primary, size: 22),
              SizedBox(width: 6),
              Text('عدد الأصناف', style: TextStyle(fontSize: 12, color: AppColors.grey)),
            ]),
            const SizedBox(height: 4),
            Text('$total',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('نفدت كميتها: $out',
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            Text('وصلت للحد الأدنى (≤ $low): $atMin',
                style: const TextStyle(fontSize: 12, color: AppColors.warning)),
          ],
        ),
      ),
    );
  }

  /// 🎁 الهدايا: سطران ثابتان (حسابي / الشركة).
  Widget _giftsBox(ReportData d, String cur) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.card_giftcard, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('هدايا على حسابي: ${d.giftsMineQty} — تكلفتها ${Fmt.money(d.giftsMineCost, cur)}',
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.card_giftcard, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('هدايا الشركة: ${d.giftsCompanyQty} — مجانية',
                    style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 💼 الأرباح بالمعادلات الطبيعية: مبيعات − تكلفة البضاعة المباعة − مصاريف.
  Widget _performanceBox(ReportData d, SettingsProvider s, String cur) {
    Widget row(String k, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
              Text(v,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : null, color: color, fontSize: bold ? 15 : 14)),
            ],
          ),
        );
    final gross = d.grossProfit;
    final net = d.netProfit;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, size: 20),
              SizedBox(width: 6),
              Text('الأرباح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            row('المبيعات', Fmt.money(d.sales, cur)),
            row('تكلفة البضاعة المباعة', Fmt.money(d.cost, cur)),
            row('الربح الإجمالي', Fmt.money(gross, cur),
                bold: true, color: gross >= 0 ? AppColors.success : AppColors.danger),
            row('المصاريف', Fmt.money(d.expensesTotal, cur)),
            const Divider(),
            row('الربح الصافي بالليرة', Fmt.money(net, cur),
                bold: true, color: net >= 0 ? AppColors.success : AppColors.danger),
            row('سعر الصرف الحالي', s.dollarRate > 0 ? Fmt.num2(s.dollarRate) : '-'),
            row('الربح الصافي بالدولار',
                s.dollarRate > 0
                    ? '\$${Fmt.num2(double.parse((net / s.dollarRate).toStringAsFixed(2)))}'
                    : '-',
                bold: true),
          ],
        ),
      ),
    );
  }

  Widget _capitalHistory(SettingsProvider s) {
    final last = _snaps.length > 12 ? _snaps.sublist(_snaps.length - 12) : _snaps;
    if (last.length < 2) {
      return const SizedBox.shrink();
    }
    return _chartCard(
      'تطور رأس المال بالدولار (12 شهراً)\n(بضاعة + صندوق + ديون الزبائن)',
      LineChart(LineChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (last.length / 5).ceilToDouble().clamp(1, 100),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= last.length) return const SizedBox();
                return Text(last[i].month.substring(2), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < last.length; i++) FlSpot(i.toDouble(), last[i].capitalUsd)],
            isCurved: true,
            color: _palette[1],
            barWidth: 3,
          ),
        ],
      )),
    );
  }

  Widget _netBox(ReportData d, String cur, double sell) {
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
            Text('ربحت ${Fmt.money(d.grossProfit, cur)}${_usd(d.grossProfit, sell)}',
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
                Text('${Fmt.money(d.netProfit, cur)}${_usd(d.netProfit, sell)}',
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

  Widget _capitalCard(CapitalSummary c, String cur, double rate) {
    Widget big(String emoji, String title, String sub, double v, Color color) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: color.withValues(alpha: 0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                      Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.grey)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(Fmt.money(v, cur),
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                      ),
                      Text(
                        rate > 0
                            ? '(ما يعادل ${Fmt.num2(v / rate < 100 ? double.parse((v / rate).toStringAsFixed(2)) : (v / rate).roundToDouble())}\$)'
                            : '(حدّد سعر الدولار من الإعدادات)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    Widget row(String k, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(k), Text(Fmt.money(v, cur))],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text('رأس المال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          big('💰', 'رأس المال كـ "بضاعة"', 'البضاعة في المخزن بسعر الشراء فقط', c.stockBuy,
              const Color(0xFF2563EB)),
          big('💵', 'رأس المال كـ "صندوق (درج)"', 'النقد الموجود في الصندوق فقط', c.cash,
              AppColors.success),
          big('🏦', 'إجمالي رأس المال الكامل', 'البضاعة + نقد الصندوق', c.stockAndCash,
              const Color(0xFF7C3AED)),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('معلومات إضافية (لا تدخل في الإجمالي أعلاه)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  row('البضاعة كاملة بسعر البيع', c.stockSell),
                  row('الربح المتوقع من المخزون', c.expectedProfit),
                  row('ديون الزبائن (نقدية متوقعة)', c.customersOwed),
                  row('مستحقات الموردين', c.suppliersOwed),
                ],
              ),
            ),
          ),
        ],
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
