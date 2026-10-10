import '../../data/models/expense.dart';
import '../../data/models/invoice.dart';
import 'period.dart';

class ProductStat {
  final int productId;
  String name;
  int qty = 0;
  double revenue = 0;
  double profit = 0;
  ProductStat(this.productId, this.name);
}

class SeriesPoint {
  final String label;
  final double sales;
  final double profit;
  SeriesPoint(this.label, this.sales, this.profit);
}

/// حسابات التقارير لفترة محددة (مبيعات، ربح، مصاريف، صافي).
class ReportData {
  final PeriodRange range;
  final List<Invoice> invoices;
  final List<Expense> expenses;

  ReportData({
    required this.range,
    required List<Invoice> allInvoices,
    required List<Expense> allExpenses,
  })  : invoices = allInvoices.where((i) => range.contains(i.date)).toList(),
        expenses = allExpenses.where((e) => range.contains(e.date)).toList();

  double get sales => invoices.fold(0, (s, i) => s + i.total);
  double get cost => invoices.fold(0, (s, i) => s + i.totalCost);

  /// الربح قبل المصاريف (مبيعات − تكلفة البضاعة المباعة).
  double get grossProfit => sales - cost;
  double get expensesTotal => expenses.fold(0, (s, e) => s + e.amount);

  /// الربح الصافي النهائي بعد كل المصاريف.
  double get netProfit => grossProfit - expensesTotal;
  double get discountsTotal => invoices.fold(0, (s, i) => s + i.totalDiscount);

  /// المصاريف حسب التصنيف، من الأكبر للأصغر.
  List<MapEntry<String, double>> get expensesByCategory {
    final m = <String, double>{};
    for (final e in expenses) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// نسبة تصنيف من إجمالي المصاريف (0..100).
  double percentOfExpenses(double v) => expensesTotal == 0 ? 0 : v / expensesTotal * 100;

  Map<int, ProductStat> get productStats {
    final m = <int, ProductStat>{};
    for (final inv in invoices) {
      for (final it in inv.items) {
        if (it.isGift) continue;
        final s = m.putIfAbsent(it.productId, () => ProductStat(it.productId, it.productName));
        s.qty += it.soldQty;
        s.revenue += inv.netOf(it);
        s.profit += inv.profitOf(it);
      }
    }
    return m;
  }

  List<ProductStat> topByProfit([int n = 5]) {
    final l = productStats.values.toList()..sort((a, b) => b.profit.compareTo(a.profit));
    return l.take(n).toList();
  }

  List<ProductStat> topByQty([int n = 5]) {
    final l = productStats.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));
    return l.take(n).toList();
  }

  List<MapEntry<String, double>> topCustomers([int n = 5]) {
    final m = <String, double>{};
    for (final inv in invoices) {
      m[inv.customerName] = (m[inv.customerName] ?? 0) + inv.total;
    }
    final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return l.take(n).toList();
  }

  /// سلسلة المبيعات والأرباح: يومية إن كانت الفترة قصيرة وإلا شهرية.
  List<SeriesPoint> get series {
    if (invoices.isEmpty) return [];
    final dates = invoices.map((i) => i.date).toList()..sort();
    final first = DateTime(dates.first.year, dates.first.month, dates.first.day);
    final last = DateTime(dates.last.year, dates.last.month, dates.last.day);
    final daily = last.difference(first).inDays <= 62;
    final sales = <String, double>{};
    final profit = <String, double>{};
    final order = <String>[];
    final sorted = [...invoices]..sort((a, b) => a.date.compareTo(b.date));
    for (final inv in sorted) {
      final key = daily
          ? '${inv.date.month}/${inv.date.day}'
          : '${inv.date.year}/${inv.date.month.toString().padLeft(2, '0')}';
      if (!sales.containsKey(key)) order.add(key);
      sales[key] = (sales[key] ?? 0) + inv.total;
      profit[key] = (profit[key] ?? 0) + inv.totalProfit;
    }
    return [for (final k in order) SeriesPoint(k, sales[k]!, profit[k]!)];
  }
}
