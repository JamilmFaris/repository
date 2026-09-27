import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/settings_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvoiceProvider>();
    final prod = context.watch<ProductProvider>();
    final settings = context.watch<SettingsProvider>();
    final r = context.read<ReportProvider>()..update(inv.invoices, prod.products);

    final last14 = r.last14DaysProfit();
    final profitByProduct = r.profitByProduct;
    final soldByProduct = r.soldQtyByProduct;

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('إجمالي الربح', Fmt.money(r.totalProfit, settings.currency), Icons.trending_up, AppColors.success),
              _statCard('إجمالي المبيعات', Fmt.money(r.totalSales, settings.currency), Icons.attach_money, AppColors.primary),
              _statCard('تكلفة البضاعة', Fmt.money(r.totalCost, settings.currency), Icons.shopping_cart, AppColors.warning),
              _statCard('قيمة المخزون', Fmt.money(r.inventoryValue, settings.currency), Icons.warehouse, AppColors.primaryDark),
              _statCard('الربح المتوقع', Fmt.money(r.expectedProfit, settings.currency), Icons.auto_graph, AppColors.success),
              _statCard('عدد الأصناف', '${r.productsCount}', Icons.inventory_2, AppColors.primary),
              _statCard('عدد الفواتير', '${r.invoicesCount}', Icons.receipt, AppColors.warning),
            ],
          ),
          const SizedBox(height: 16),
          _chartCard('الأرباح في آخر 14 يوم', _lineChart(last14)),
          _chartCard('ربح كل صنف', _barChartProfit(profitByProduct, prod.products.map((e) => e.name).toList())),
          _chartCard('الأصناف الأكثر مبيعاً', _barChartSold(soldByProduct, prod.products.map((e) => e.name).toList())),
          _chartCard('توزيع الأرباح', _pieChart(profitByProduct, prod.products.map((e) => e.name).toList())),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 6),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.grey), overflow: TextOverflow.ellipsis))]),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );

  Widget _chartCard(String title, Widget chart) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(height: 220, child: chart),
        ],
      ),
    ),
  );

  Widget _lineChart(List<MapEntry<DateTime, double>> data) {
    return LineChart(LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(leftTitles: AxisTitles(), rightTitles: AxisTitles(), topTitles: AxisTitles()),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.15)),
        ),
      ],
    ));
  }

  Widget _barChartProfit(Map<int, double> map, List<String> names) {
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    return BarChart(BarChartData(
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(), rightTitles: const AxisTitles(), topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= top.length) return const SizedBox();
          return Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(top[i].key.toString(), style: const TextStyle(fontSize: 10)));
        })),
      ),
      barGroups: top.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: e.value.value, color: AppColors.success, width: 16, borderRadius: BorderRadius.circular(4)),
      ])).toList(),
    ));
  }

  Widget _barChartSold(Map<int, int> map, List<String> names) {
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    return BarChart(BarChartData(
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(), rightTitles: const AxisTitles(), topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= top.length) return const SizedBox();
          return Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(top[i].key.toString(), style: const TextStyle(fontSize: 10)));
        })),
      ),
      barGroups: top.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: e.value.value.toDouble(), color: AppColors.primary, width: 16, borderRadius: BorderRadius.circular(4)),
      ])).toList(),
    ));
  }

  Widget _pieChart(Map<int, double> map, List<String> names) {
    final entries = map.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const Center(child: Text('لا توجد بيانات'));
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.danger, AppColors.primaryDark, Colors.purple];
    return PieChart(PieChartData(
      sections: entries.asMap().entries.map((e) => PieChartSectionData(
        value: e.value.value,
        color: colors[e.key % colors.length],
        title: '${e.value.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      )).toList(),
      sectionsSpace: 2,
      centerSpaceRadius: 40,
    ));
  }
}