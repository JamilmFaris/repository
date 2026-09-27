import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class InvoiceRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Invoice>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('invoices', orderBy: 'id DESC');
    final invoices = <Invoice>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final itemRows = await db.query('invoice_items', where: 'invoiceId = ?', whereArgs: [id]);
      final items = itemRows.map(InvoiceItem.fromMap).toList();
      invoices.add(Invoice.fromMap(r, items));
    }
    return invoices;
  }

  Future<int> insert(Invoice inv) async {
    final db = await _db.database;
    final id = await db.insert('invoices', inv.toMap()..remove('id'));
    for (final item in inv.items) {
      await db.insert('invoice_items', item.toMap()..remove('id')..['invoiceId'] = id);
    }
    return id;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('invoice_items', where: 'invoiceId = ?', whereArgs: [id]);
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> nextNumber() async {
    final db = await _db.database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM invoices');
    final c = (r.first['c'] as int) + 1;
    return 'INV-${c.toString().padLeft(4, '0')}';
  }
}