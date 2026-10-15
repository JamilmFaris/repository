import '../../data/database/database_helper.dart';
import '../../data/repositories/invoice_repository.dart';

class CashMovement {
  final int id;
  final String type; // in | out
  final double amount;
  final String reason;
  final DateTime date;
  CashMovement(this.id, this.type, this.amount, this.reason, this.date);
  bool get isIn => type == 'in';
}

class CashCount {
  final int id;
  final DateTime date;
  final double theoretical;
  final double actual;
  final double diff;
  final String note;
  CashCount(this.id, this.date, this.theoretical, this.actual, this.diff, this.note);
}

/// تفصيل رصيد الدرج النظري منذ آخر جرد.
class CashBreakdown {
  final bool hasBaseline;
  final double baseline;
  final DateTime? since;
  final double cashSales;
  final double collections;
  final double manualIn;
  final double supplierPayments;
  final double expenses;
  final double shipping;
  final double refunds;
  final double manualOut;

  CashBreakdown({
    required this.hasBaseline,
    this.baseline = 0,
    this.since,
    this.cashSales = 0,
    this.collections = 0,
    this.manualIn = 0,
    this.supplierPayments = 0,
    this.expenses = 0,
    this.shipping = 0,
    this.refunds = 0,
    this.manualOut = 0,
  });

  /// الرصيد النظري = الافتتاحي + الوارد − الصادر.
  double get theoretical =>
      baseline +
      cashSales +
      collections +
      manualIn -
      supplierPayments -
      expenses -
      shipping -
      refunds -
      manualOut;
}

/// حساب رصيد الدرج: آخر جرد محفوظ + الحركات النقدية بعده.
/// كل المقبوضات والمدفوعات تُعتبر نقدية (لا تمييز لطريقة الدفع).
class CashService {
  static final _db = DatabaseHelper.instance;

  static Future<CashCount?> lastCount() async {
    final db = await _db.database;
    final rows = await db.query('cash_counts', orderBy: 'date DESC, id DESC', limit: 1);
    return rows.isEmpty ? null : _count(rows.first);
  }

  static CashCount _count(Map<String, Object?> r) => CashCount(
        r['id'] as int,
        DateTime.parse(r['date'] as String),
        (r['theoretical'] as num).toDouble(),
        (r['actual'] as num).toDouble(),
        (r['diff'] as num).toDouble(),
        r['note'] as String? ?? '',
      );

  static Future<List<CashCount>> counts() async {
    final db = await _db.database;
    final rows = await db.query('cash_counts', orderBy: 'date DESC, id DESC');
    return rows.map(_count).toList();
  }

  static Future<List<CashMovement>> movements() async {
    final db = await _db.database;
    final rows = await db.query('cash_movements', orderBy: 'date DESC, id DESC');
    return rows
        .map((r) => CashMovement(
              r['id'] as int,
              r['type'] as String,
              (r['amount'] as num).toDouble(),
              r['reason'] as String? ?? '',
              DateTime.parse(r['date'] as String),
            ))
        .toList();
  }

  static Future<double> _sum(String sql, List<Object?> args) async {
    final db = await _db.database;
    final r = await db.rawQuery(sql, args);
    return ((r.first.values.first ?? 0) as num).toDouble();
  }

  static Future<CashBreakdown> compute() async {
    final last = await lastCount();
    if (last == null) return CashBreakdown(hasBaseline: false);
    final since = last.date;
    final iso = since.toIso8601String();
    final db = await _db.database;

    // مبيعات نقدية + مرتجعات نقدية
    final invoices = await InvoiceRepository().getAll();
    final retRows = await db.query('returns', orderBy: 'date ASC, id ASC');
    final retsByInvoice = <int, List<Map<String, Object?>>>{};
    for (final r in retRows) {
      retsByInvoice.putIfAbsent(r['invoiceId'] as int, () => []).add(r);
    }
    var cashSales = 0.0, refunds = 0.0;
    for (final inv in invoices) {
      final rets = retsByInvoice[inv.id] ?? const [];
      final allRefunds =
          rets.fold<double>(0, (s, r) => s + (r['refundAmount'] as num).toDouble());
      final original = inv.total + allRefunds;
      final paid = inv.paidAmount ?? original;
      if (inv.date.isAfter(since)) cashSales += paid;
      // المرتجع يخرج نقداً بقدر ما يتجاوز المدفوعُ الإجماليَّ الجديد
      var t = original;
      for (final r in rets) {
        final before = t;
        t -= (r['refundAmount'] as num).toDouble();
        final cashOut = (paid - t).clamp(0, double.infinity) -
            (paid - before).clamp(0, double.infinity);
        if (DateTime.parse(r['date'] as String).isAfter(since)) {
          refunds += cashOut.toDouble();
        }
      }
    }

    final collections = await _sum(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE date > ?', [iso]);
    final supplierPay = await _sum(
            'SELECT COALESCE(SUM(amount),0) FROM supplier_payments WHERE date > ?', [iso]) +
        await _sum(
            'SELECT COALESCE(SUM(paidAmount),0) FROM purchase_invoices WHERE date > ?', [iso]);
    final shipping = await _sum(
        'SELECT COALESCE(SUM(shippingCost + otherCost),0) FROM purchase_invoices WHERE date > ?',
        [iso]);
    final expenses = await _sum(
        'SELECT COALESCE(SUM(amount),0) FROM expenses WHERE date > ? AND invoiceId IS NULL',
        [iso]);
    final manualIn = await _sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_movements WHERE type = 'in' AND date > ?",
        [iso]);
    final manualOut = await _sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_movements WHERE type = 'out' AND date > ?",
        [iso]);

    return CashBreakdown(
      hasBaseline: true,
      baseline: last.actual,
      since: since,
      cashSales: cashSales,
      collections: collections,
      manualIn: manualIn,
      supplierPayments: supplierPay,
      expenses: expenses,
      shipping: shipping,
      refunds: refunds,
      manualOut: manualOut,
    );
  }

  static Future<void> addMovement(String type, double amount, String reason) async {
    final db = await _db.database;
    await db.insert('cash_movements', {
      'type': type,
      'amount': amount,
      'reason': reason,
      'date': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteMovement(int id) async {
    final db = await _db.database;
    await db.delete('cash_movements', where: 'id = ?', whereArgs: [id]);
  }

  /// يحفظ جرداً (يصبح خط الأساس الجديد). [theoretical] = الرصيد النظري لحظة الجرد.
  static Future<void> saveCount({
    required double theoretical,
    required double actual,
    String note = '',
  }) async {
    final db = await _db.database;
    await db.insert('cash_counts', {
      'date': DateTime.now().toIso8601String(),
      'theoretical': theoretical,
      'actual': actual,
      'diff': actual - theoretical,
      'note': note,
    });
  }
}
