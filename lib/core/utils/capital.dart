import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';
import '../../providers/party_provider.dart';

/// أرقام رأس المال (لا تعتمد على فترة التقرير).
class CapitalSummary {
  final double stockBuy;
  final double stockSell;
  final double customersOwed;
  final double suppliersOwed;

  /// رصيد الصندوق (الدرج) — صفر إلى أن تُضاف إدارة الصندوق.
  final double cash;

  CapitalSummary({
    required this.stockBuy,
    required this.stockSell,
    required this.customersOwed,
    required this.suppliersOwed,
    this.cash = 0,
  });

  double get expectedProfit => stockSell - stockBuy;

  /// رأس المال الحالي = المخزون بسعر الشراء + النقدية + ديون الزبائن.
  double get capital => stockBuy + cash + customersOwed;

  static CapitalSummary compute({
    required List<Product> products,
    required List<Invoice> invoices,
    required PartyProvider parties,
    double cash = 0,
  }) {
    final stockBuy = products.fold<double>(0, (s, p) => s + p.buyPrice * p.quantity);
    final stockSell = products.fold<double>(0, (s, p) => s + p.sellPrice * p.quantity);
    final debts = invoices.fold<double>(0, (s, i) => s + i.owed) -
        parties.customerPayments.fold<double>(0, (s, p) => s + p.amount);
    final suppliers =
        parties.suppliers.fold<double>(0, (s, x) => s + parties.supplierBalance(x.id!));
    return CapitalSummary(
      stockBuy: stockBuy,
      stockSell: stockSell,
      customersOwed: debts < 0 ? 0 : debts,
      suppliersOwed: suppliers < 0 ? 0 : suppliers,
      cash: cash,
    );
  }
}

/// لقطة شهرية لرأس المال بالدولار.
class CapitalSnapshot {
  final String month; // yyyy-MM
  final double capitalUsd;
  final double rate;
  final double capitalSyp;
  final DateTime date;
  CapitalSnapshot(this.month, this.capitalUsd, this.rate, this.capitalSyp, this.date);
}

class CapitalSnapshots {
  static final _db = DatabaseHelper.instance;

  static String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static Future<List<CapitalSnapshot>> all() async {
    final db = await _db.database;
    final rows = await db.query('capital_snapshots', orderBy: 'month ASC');
    return rows
        .map((r) => CapitalSnapshot(
              r['month'] as String,
              (r['capitalUsd'] as num).toDouble(),
              (r['rate'] as num).toDouble(),
              (r['capitalSyp'] as num).toDouble(),
              DateTime.parse(r['date'] as String),
            ))
        .toList();
  }

  /// يحفظ/يحدّث لقطة الشهر الحالي. [overwrite] = false يتركها إن وُجدت.
  static Future<void> save({
    required double capitalSyp,
    required double buyRate,
    bool overwrite = true,
  }) async {
    if (buyRate <= 0 || capitalSyp <= 0) return;
    final db = await _db.database;
    final now = DateTime.now();
    final key = monthKey(now);
    if (!overwrite) {
      final ex = await db.query('capital_snapshots', where: 'month = ?', whereArgs: [key]);
      if (ex.isNotEmpty) return;
    }
    await db.insert(
      'capital_snapshots',
      {
        'month': key,
        'capitalUsd': capitalSyp / buyRate,
        'rate': buyRate,
        'capitalSyp': capitalSyp,
        'date': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
