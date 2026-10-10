import 'package:flutter/foundation.dart';
import '../data/models/invoice.dart';
import '../data/models/product.dart';

class ReportProvider extends ChangeNotifier {
  List<Invoice> _invoices = [];
  List<Product> _products = [];

  void update(List<Invoice> inv, List<Product> prods) {
    _invoices = inv;
    _products = prods;
    notifyListeners();
  }

  double get totalSales => _invoices.fold(0, (s, i) => s + i.total);
  double get totalCost => _invoices.fold(0, (s, i) => s + i.totalCost);
  double get totalProfit => totalSales - totalCost;
  double get inventoryValue => _products.fold(0, (s, p) => s + (p.buyPrice * p.quantity));
  double get expectedProfit => _products.fold(0, (s, p) => s + (p.profitPerUnit * p.quantity));
  int get productsCount => _products.length;
  int get invoicesCount => _invoices.length;

  /// مجموع الكميات المباعة لكل منتج (منطق التجميع التلقائي)
  Map<int, int> get soldQtyByProduct {
    final m = <int, int>{};
    for (final inv in _invoices) {
      for (final it in inv.items) {
        m[it.productId] = (m[it.productId] ?? 0) + it.soldQty;
      }
    }
    return m;
  }

  Map<int, double> get profitByProduct {
    final m = <int, double>{};
    for (final inv in _invoices) {
      for (final it in inv.items) {
        m[it.productId] = (m[it.productId] ?? 0) + inv.profitOf(it);
      }
    }
    return m;
  }

  /// آخر 14 يوم ربح
  List<MapEntry<DateTime, double>> last14DaysProfit() {
    final now = DateTime.now();
    final result = <MapEntry<DateTime, double>>[];
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      double profit = 0;
      for (final inv in _invoices) {
        if (!inv.date.isBefore(day) && inv.date.isBefore(next)) profit += inv.totalProfit;
      }
      result.add(MapEntry(day, profit));
    }
    return result;
  }

  /// أفضل الزبائن
  Map<String, double> topCustomers() {
    final m = <String, double>{};
    for (final inv in _invoices) {
      m[inv.customerName] = (m[inv.customerName] ?? 0) + inv.total;
    }
    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(10));
  }
}