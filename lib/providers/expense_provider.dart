import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';
import '../data/models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<Expense> expenses = [];

  Future<void> load() async {
    final db = await _db.database;
    final rows = await db.query('expenses', orderBy: 'date DESC, id DESC');
    expenses = rows.map(Expense.fromMap).toList();
    notifyListeners();
  }

  Future<void> add(Expense e) async {
    final db = await _db.database;
    await db.insert('expenses', e.toMap()..remove('id'));
    await load();
  }

  Future<void> update(Expense e) async {
    final db = await _db.database;
    await db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    await load();
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('expenses', where: 'id = ? AND invoiceId IS NULL', whereArgs: [id]);
    await load();
  }

  List<Expense> inRange(DateTime start, DateTime end) =>
      expenses.where((e) => !e.date.isBefore(start) && e.date.isBefore(end)).toList();
}
