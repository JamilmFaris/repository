import '../database/database_helper.dart';
import '../models/party.dart';
import '../models/purchase.dart';
import '../models/reservation.dart';

/// وصول لجداول الزبائن والموردين ودفعاتهم، وفواتير الشراء والحجوزات.
class PartyRepository {
  final _db = DatabaseHelper.instance;

  // ---------- الزبائن ----------
  Future<List<Party>> customers() async {
    final db = await _db.database;
    return (await db.query('customers', orderBy: 'name ASC')).map(Party.fromMap).toList();
  }

  Future<int> addCustomer(Party c) async {
    final db = await _db.database;
    return db.insert('customers', c.toMap()..remove('id'));
  }

  Future<void> updateCustomer(Party c) async {
    final db = await _db.database;
    await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await _db.database;
    await db.transaction((t) async {
      await t.delete('payments', where: 'customerId = ?', whereArgs: [id]);
      await t.update('invoices', {'customerId': null}, where: 'customerId = ?', whereArgs: [id]);
      await t.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<PartyPayment>> customerPayments() async {
    final db = await _db.database;
    final rows = await db.query('payments', orderBy: 'date DESC');
    return rows
        .map((m) => PartyPayment(
              id: m['id'] as int,
              partyId: m['customerId'] as int,
              refId: m['invoiceId'] as int?,
              amount: (m['amount'] as num).toDouble(),
              date: DateTime.parse(m['date'] as String),
              note: m['note'] as String? ?? '',
            ))
        .toList();
  }

  Future<void> addCustomerPayment(PartyPayment p) async {
    final db = await _db.database;
    await db.insert('payments', {
      'customerId': p.partyId,
      'invoiceId': p.refId,
      'amount': p.amount,
      'date': p.date.toIso8601String(),
      'note': p.note,
    });
  }

  Future<void> deleteCustomerPayment(int id) async {
    final db = await _db.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- الموردون ----------
  Future<List<Party>> suppliers() async {
    final db = await _db.database;
    return (await db.query('suppliers', orderBy: 'name ASC')).map(Party.fromMap).toList();
  }

  Future<int> addSupplier(Party s) async {
    final db = await _db.database;
    return db.insert('suppliers', s.toMap()..remove('id'));
  }

  Future<void> updateSupplier(Party s) async {
    final db = await _db.database;
    await db.update('suppliers', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSupplier(int id) async {
    final db = await _db.database;
    await db.transaction((t) async {
      final ps = await t.query('purchase_invoices', where: 'supplierId = ?', whereArgs: [id]);
      for (final p in ps) {
        await t.delete('purchase_items', where: 'purchaseId = ?', whereArgs: [p['id']]);
      }
      await t.delete('purchase_invoices', where: 'supplierId = ?', whereArgs: [id]);
      await t.delete('supplier_payments', where: 'supplierId = ?', whereArgs: [id]);
      await t.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<PartyPayment>> supplierPayments() async {
    final db = await _db.database;
    final rows = await db.query('supplier_payments', orderBy: 'date DESC');
    return rows
        .map((m) => PartyPayment(
              id: m['id'] as int,
              partyId: m['supplierId'] as int,
              refId: m['purchaseId'] as int?,
              amount: (m['amount'] as num).toDouble(),
              date: DateTime.parse(m['date'] as String),
              note: m['note'] as String? ?? '',
            ))
        .toList();
  }

  Future<void> addSupplierPayment(PartyPayment p) async {
    final db = await _db.database;
    await db.insert('supplier_payments', {
      'supplierId': p.partyId,
      'purchaseId': p.refId,
      'amount': p.amount,
      'date': p.date.toIso8601String(),
      'note': p.note,
    });
  }

  Future<void> deleteSupplierPayment(int id) async {
    final db = await _db.database;
    await db.delete('supplier_payments', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- فواتير الشراء ----------
  Future<List<PurchaseInvoice>> purchases() async {
    final db = await _db.database;
    final rows = await db.query('purchase_invoices', orderBy: 'date DESC, id DESC');
    final result = <PurchaseInvoice>[];
    for (final r in rows) {
      final items = (await db.query('purchase_items',
              where: 'purchaseId = ?', whereArgs: [r['id']], orderBy: 'id ASC'))
          .map(PurchaseItem.fromMap)
          .toList();
      result.add(PurchaseInvoice.fromMap(r, items));
    }
    return result;
  }

  /// يحفظ فاتورة الشراء: يزيد الكميات ويحدّث سعر شراء كل صنف لآخر سعر.
  Future<void> addPurchase(PurchaseInvoice p) async {
    final db = await _db.database;
    await db.transaction((t) async {
      final id = await t.insert('purchase_invoices', p.toMap()..remove('id'));
      for (final it in p.items) {
        await t.insert('purchase_items', it.toMap()..remove('id')..['purchaseId'] = id);
        if (it.usdPrice != null) {
          await t.rawUpdate(
              'UPDATE products SET quantity = quantity + ?, buyPrice = ?, buyPriceUsd = ? WHERE id = ?',
              [it.quantity, it.buyPrice, it.usdPrice, it.productId]);
        } else {
          await t.rawUpdate(
              'UPDATE products SET quantity = quantity + ?, buyPrice = ? WHERE id = ?',
              [it.quantity, it.buyPrice, it.productId]);
        }
      }
    });
  }

  /// حذف فاتورة شراء: تُنقَص الكميات المضافة منها (السعر يبقى كما هو).
  Future<void> deletePurchase(int id) async {
    final db = await _db.database;
    await db.transaction((t) async {
      final items = await t.query('purchase_items', where: 'purchaseId = ?', whereArgs: [id]);
      for (final it in items) {
        await t.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?',
            [it['quantity'], it['productId']]);
      }
      await t.delete('purchase_items', where: 'purchaseId = ?', whereArgs: [id]);
      await t.delete('supplier_payments', where: 'purchaseId = ?', whereArgs: [id]);
      await t.delete('purchase_invoices', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- الحجوزات ----------
  Future<List<Reservation>> reservations() async {
    final db = await _db.database;
    final rows = await db.query('reservations', orderBy: 'id DESC');
    final result = <Reservation>[];
    for (final r in rows) {
      final items = (await db.query('reservation_items',
              where: 'reservationId = ?', whereArgs: [r['id']]))
          .map((m) => ReservationItem(
                productId: m['productId'] as int,
                productName: m['productName'] as String,
                quantity: m['quantity'] as int,
              ))
          .toList();
      result.add(Reservation(
        id: r['id'] as int,
        customerName: r['customerName'] as String,
        date: DateTime.parse(r['date'] as String),
        dueDate: r['dueDate'] == null ? null : DateTime.parse(r['dueDate'] as String),
        notes: r['notes'] as String? ?? '',
        status: r['status'] as String? ?? 'open',
        items: items,
      ));
    }
    return result;
  }

  Future<void> addReservation(Reservation r) async {
    final db = await _db.database;
    await db.transaction((t) async {
      final id = await t.insert('reservations', {
        'customerName': r.customerName,
        'date': r.date.toIso8601String(),
        'dueDate': r.dueDate?.toIso8601String(),
        'notes': r.notes,
        'status': r.status,
      });
      for (final it in r.items) {
        await t.insert('reservation_items', {
          'reservationId': id,
          'productId': it.productId,
          'productName': it.productName,
          'quantity': it.quantity,
        });
      }
    });
  }

  Future<void> setReservationStatus(int id, String status) async {
    final db = await _db.database;
    await db.update('reservations', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteReservation(int id) async {
    final db = await _db.database;
    await db.transaction((t) async {
      await t.delete('reservation_items', where: 'reservationId = ?', whereArgs: [id]);
      await t.delete('reservations', where: 'id = ?', whereArgs: [id]);
    });
  }
}
