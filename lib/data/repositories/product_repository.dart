import '../database/database_helper.dart';
import '../models/product.dart';

class ProductRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Product>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insert(Product p) async {
    final db = await _db.database;
    return db.insert('products', p.toMap()..remove('id'));
  }

  Future<void> update(Product p) async {
    final db = await _db.database;
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> updateQuantity(int id, int qty) async {
    final db = await _db.database;
    await db.update('products', {'quantity': qty}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}