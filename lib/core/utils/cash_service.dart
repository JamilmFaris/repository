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

  /// للرصيد الافتتاحي: المبلغ المُدخل بالدولار وسعر الصرف وقت الإدخال (0 = أُدخل بالليرة).
  final double usdAmount;
  final double rate;
  CashCount(this.id, this.date, this.theoretical, this.actual, this.diff, this.note,
      {this.usdAmount = 0, this.rate = 0});

  bool get isOpening => note == CashService.openingNote;
  bool get enteredInUsd => usdAmount > 0;
}

/// حركة نقدية تلقائية مصدرها فاتورة أو دفعة أو مصروف (للعرض في الصندوق).
class CashEntry {
  final bool isIn;
  final double amount;
  final String label;
  final DateTime date;
  CashEntry(this.isIn, this.amount, this.label, this.date);
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
  static const openingNote = 'رصيد افتتاحي';

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
        usdAmount: ((r['usdAmount'] ?? 0) as num).toDouble(),
        rate: ((r['rate'] ?? 0) as num).toDouble(),
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

    // الدفعات التي اختار المستخدم عدم إضافتها للصندوق (inCash = 0) لا تُحتسب
    final collections = await _sum(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE date > ? AND inCash = 1', [iso]);
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

  /// الجرد الافتتاحي (الأول المسجَّل بصفة «رصيد افتتاحي») أو null.
  static Future<CashCount?> openingCount() async {
    final db = await _db.database;
    final rows = await db.query('cash_counts',
        where: 'note = ?', whereArgs: [openingNote], orderBy: 'date ASC, id ASC', limit: 1);
    return rows.isEmpty ? null : _count(rows.first);
  }

  /// يسجّل الرصيد الافتتاحي؛ [usd] > 0 إن أُدخل بالدولار (والمبلغ [amount] بالليرة محوَّل بـ [rate]).
  static Future<void> saveOpening(double amount, {double usd = 0, double rate = 0}) async {
    final db = await _db.database;
    await db.insert('cash_counts', {
      'date': DateTime.now().toIso8601String(),
      'theoretical': amount,
      'actual': amount,
      'diff': 0,
      'note': openingNote,
      'usdAmount': usd,
      'rate': rate,
    });
  }

  /// يعدّل الرصيد الافتتاحي المسجَّل بالخطأ (يبقى تاريخه فيبقى حساب ما بعده سليماً).
  static Future<void> updateOpening(int id, double amount, {double usd = 0, double rate = 0}) async {
    final db = await _db.database;
    await db.update(
      'cash_counts',
      {'theoretical': amount, 'actual': amount, 'diff': 0, 'usdAmount': usd, 'rate': rate},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// الحركات التلقائية بعد آخر جرد: ما دخل/خرج من الدرج من الفواتير والدفعات والمصاريف.
  static Future<List<CashEntry>> autoEntries() async {
    final last = await lastCount();
    if (last == null) return [];
    final since = last.date;
    final iso = since.toIso8601String();
    final db = await _db.database;
    final out = <CashEntry>[];

    final invoices = await InvoiceRepository().getAll();
    final retRows = await db.query('returns');
    final refundsByInvoice = <int, double>{};
    for (final r in retRows) {
      final id = r['invoiceId'] as int;
      refundsByInvoice[id] = (refundsByInvoice[id] ?? 0) + (r['refundAmount'] as num).toDouble();
    }
    for (final inv in invoices) {
      if (!inv.date.isAfter(since)) continue;
      final original = inv.total + (refundsByInvoice[inv.id] ?? 0);
      final paid = inv.paidAmount ?? original;
      if (paid <= 0) continue;
      out.add(CashEntry(true, paid, 'فاتورة ${inv.number} — ${inv.customerName}', inv.date));
    }

    Future<void> rows(String sql, bool isIn, String Function(Map<String, Object?>) label,
        {String amountKey = 'amount'}) async {
      for (final r in await db.rawQuery(sql, [iso])) {
        final amount = (r[amountKey] as num).toDouble();
        if (amount <= 0) continue;
        out.add(CashEntry(isIn, amount, label(r), DateTime.parse(r['date'] as String)));
      }
    }

    await rows(
        'SELECT p.amount, p.date, c.name FROM payments p LEFT JOIN customers c ON c.id = p.customerId '
        'WHERE p.date > ? AND p.inCash = 1',
        true,
        (r) => 'دفعة من ${r['name'] ?? 'زبون'}');
    await rows(
        'SELECT sp.amount, sp.date, s.name FROM supplier_payments sp '
        'LEFT JOIN suppliers s ON s.id = sp.supplierId WHERE sp.date > ?',
        false,
        (r) => 'دفعة للمورّد ${r['name'] ?? ''}');
    await rows(
        'SELECT pi.paidAmount AS amount, pi.date, s.name FROM purchase_invoices pi '
        'LEFT JOIN suppliers s ON s.id = pi.supplierId WHERE pi.date > ?',
        false,
        (r) => 'فاتورة شراء — ${r['name'] ?? ''}');
    await rows(
        'SELECT (shippingCost + otherCost) AS amount, date FROM purchase_invoices WHERE date > ?',
        false,
        (_) => 'شحن وجمارك');
    await rows(
        'SELECT amount, date, category FROM expenses WHERE date > ? AND invoiceId IS NULL',
        false,
        (r) => 'مصروف: ${r['category']}');

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}
