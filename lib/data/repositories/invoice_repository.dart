import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

/// سطر مرتجع: كمية من سطر فاتورة ومبلغ الاسترجاع.
class ReturnLine {
  final InvoiceItem item;
  final int qty;
  final double refund;
  ReturnLine(this.item, this.qty, this.refund);
}

class InvoiceRepository {
  static const giftCategory = 'العروض';

  final _db = DatabaseHelper.instance;

  Future<List<Invoice>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('invoices', orderBy: 'id DESC');
    final invoices = <Invoice>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final itemRows = await db.query('invoice_items',
          where: 'invoiceId = ?', whereArgs: [id], orderBy: 'id ASC');
      final items = itemRows.map(InvoiceItem.fromMap).toList();
      invoices.add(Invoice.fromMap(r, items));
    }
    return invoices;
  }

  Future<void> _adjustStock(DatabaseExecutor db, int productId, int delta) async {
    if (delta == 0) return;
    await db.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?', [delta, productId]);
  }

  Future<void> _insertItems(DatabaseExecutor db, int invoiceId, List<InvoiceItem> items) async {
    for (final item in items) {
      await db.insert('invoice_items', item.toMap()..remove('id')..['invoiceId'] = invoiceId);
    }
  }

  /// يعيد حساب مصروف «العروض» (تكلفة الهدايا) المرتبط بالفاتورة.
  Future<void> _syncGiftExpense(DatabaseExecutor db, int invoiceId) async {
    await db.delete('expenses',
        where: 'invoiceId = ? AND category = ?', whereArgs: [invoiceId, giftCategory]);
    final invRows = await db.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    if (invRows.isEmpty) return;
    final itemRows =
        await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [invoiceId]);
    final items = itemRows.map(InvoiceItem.fromMap).toList();
    final cost = items.fold<double>(0, (s, i) => s + i.giftCost);
    if (cost <= 0) return;
    await db.insert('expenses', {
      'category': giftCategory,
      'amount': cost,
      'description': 'هدايا فاتورة ${invRows.first['number']}',
      'date': invRows.first['date'],
      'invoiceId': invoiceId,
    });
  }

  /// حفظ فاتورة جديدة: يخصم الكميات (مع الهدايا) ويسجّل مصروف العروض.
  Future<int> insert(Invoice inv) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final id = await txn.insert('invoices', inv.toMap()..remove('id'));
      await _insertItems(txn, id, inv.items);
      for (final it in inv.items) {
        await _adjustStock(txn, it.productId, -it.keptQty);
      }
      await _syncGiftExpense(txn, id);
      return id;
    });
  }

  /// تعديل فاتورة محفوظة: يعيد كميات السطور القديمة ثم يخصم الجديدة.
  Future<void> update(Invoice inv) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final oldRows =
          await txn.query('invoice_items', where: 'invoiceId = ?', whereArgs: [inv.id]);
      for (final r in oldRows) {
        final o = InvoiceItem.fromMap(r);
        await _adjustStock(txn, o.productId, o.keptQty);
      }
      await txn.update('invoices', inv.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [inv.id]);
      await txn.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [inv.id]);
      await _insertItems(txn, inv.id!, inv.items);
      for (final it in inv.items) {
        await _adjustStock(txn, it.productId, -it.keptQty);
      }
      await _syncGiftExpense(txn, inv.id!);
    });
  }

  /// حذف فاتورة: تُعاد الكميات الباقية (غير المرتجعة) للمخزون.
  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query('invoice_items', where: 'invoiceId = ?', whereArgs: [id]);
      for (final r in rows) {
        final o = InvoiceItem.fromMap(r);
        await _adjustStock(txn, o.productId, o.keptQty);
      }
      await txn.delete('expenses', where: 'invoiceId = ?', whereArgs: [id]);
      await txn.delete('returns', where: 'invoiceId = ?', whereArgs: [id]);
      await txn.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// مرتجع: يعيد الكميات للمخزون ويسجّل المبلغ المسترجع.
  Future<void> returnItems(int invoiceId, List<ReturnLine> lines, {String note = ''}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      for (final l in lines) {
        if (l.qty <= 0) continue;
        await txn.rawUpdate(
            'UPDATE invoice_items SET returnedQty = returnedQty + ? WHERE id = ?',
            [l.qty, l.item.id]);
        await _adjustStock(txn, l.item.productId, l.qty);
        await txn.insert('returns', {
          'invoiceId': invoiceId,
          'itemId': l.item.id,
          'productId': l.item.productId,
          'quantity': l.qty,
          'refundAmount': l.refund,
          'date': now,
          'note': note,
        });
      }
      await _syncGiftExpense(txn, invoiceId);
    });
  }

  /// إجمالي المبالغ المسترجعة لفاتورة.
  Future<Map<int, double>> refundsByInvoice() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        'SELECT invoiceId, SUM(refundAmount) AS s FROM returns GROUP BY invoiceId');
    return {for (final r in rows) r['invoiceId'] as int: (r['s'] as num).toDouble()};
  }

  /// رقم الفاتورة التالي: أكبر رقم موجود + 1 (قابل للتعديل من الشاشة).
  Future<String> nextNumber() async {
    final db = await _db.database;
    final rows = await db.query('invoices', columns: ['number']);
    var max = 0;
    for (final r in rows) {
      final n = int.tryParse((r['number'] as String).replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > max) max = n;
    }
    return '${max + 1}';
  }

  Future<bool> numberExists(String number, {int? exceptId}) async {
    final db = await _db.database;
    final r = await db.query('invoices',
        where: exceptId == null ? 'number = ?' : 'number = ? AND id != ?',
        whereArgs: exceptId == null ? [number] : [number, exceptId],
        limit: 1);
    return r.isNotEmpty;
  }
}
