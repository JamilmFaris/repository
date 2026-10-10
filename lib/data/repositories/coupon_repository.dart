import '../database/database_helper.dart';
import '../models/coupon.dart';

class CouponRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Coupon>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('coupons', orderBy: 'id DESC');
    return rows.map(Coupon.fromMap).toList();
  }

  Future<void> insert(Coupon c) async {
    final db = await _db.database;
    await db.insert('coupons', c.toMap()..remove('id'));
  }

  Future<void> setActive(int id, bool active) async {
    final db = await _db.database;
    await db.update('coupons', {'active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('coupons', where: 'id = ?', whereArgs: [id]);
  }

  Future<Coupon?> findByCode(String code) async {
    final db = await _db.database;
    final rows = await db.query('coupons',
        where: 'LOWER(code) = ?', whereArgs: [code.trim().toLowerCase()], limit: 1);
    return rows.isEmpty ? null : Coupon.fromMap(rows.first);
  }
}
