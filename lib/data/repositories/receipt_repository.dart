import '../database/database_helper.dart';
import '../models/receipt.dart';

class ReceiptRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Receipt>> all() async {
    final db = await _db.database;
    final rows = await db.query('receipts', orderBy: 'number DESC');
    return rows.map(Receipt.fromMap).toList();
  }

  /// يُنشئ الوصل ويسجّل معه دفعة على حساب الزبون في معاملة واحدة.
  Future<Receipt> create({
    required int customerId,
    required String customerName,
    required double amount,
    required String purpose,
    required String note,
    required DateTime date,
  }) async {
    final db = await _db.database;
    return db.transaction((t) async {
      final paymentId = await t.insert('payments', {
        'customerId': customerId,
        'invoiceId': null,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': purpose.isEmpty ? note : (note.isEmpty ? purpose : '$purpose - $note'),
      });
      final r = await t.rawQuery('SELECT MAX(number) AS m FROM receipts');
      final number = ((r.first['m'] as int?) ?? 0) + 1;
      final receipt = Receipt(
        number: number,
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        purpose: purpose,
        note: note,
        date: date,
        paymentId: paymentId,
      );
      final id = await t.insert('receipts', receipt.toMap()..remove('id'));
      return Receipt.fromMap(receipt.toMap()..['id'] = id);
    });
  }

  /// حذف الوصل يلغي الدفعة المرتبطة به أيضاً (فيعود الدَّين).
  Future<void> delete(Receipt r) async {
    final db = await _db.database;
    await db.transaction((t) async {
      if (r.paymentId != null) {
        await t.delete('payments', where: 'id = ?', whereArgs: [r.paymentId]);
      }
      await t.delete('receipts', where: 'id = ?', whereArgs: [r.id]);
    });
  }
}
