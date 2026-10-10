import 'package:flutter/foundation.dart';
import '../data/models/party.dart';
import '../data/models/purchase.dart';
import '../data/models/reservation.dart';
import '../data/repositories/party_repository.dart';

/// الزبائن والموردون وفواتير الشراء والحجوزات.
class PartyProvider extends ChangeNotifier {
  final _repo = PartyRepository();

  List<Party> customers = [];
  List<PartyPayment> customerPayments = [];
  List<Party> suppliers = [];
  List<PartyPayment> supplierPayments = [];
  List<PurchaseInvoice> purchases = [];
  List<Reservation> reservations = [];

  Future<void> loadAll() async {
    customers = await _repo.customers();
    customerPayments = await _repo.customerPayments();
    suppliers = await _repo.suppliers();
    supplierPayments = await _repo.supplierPayments();
    purchases = await _repo.purchases();
    reservations = await _repo.reservations();
    notifyListeners();
  }

  // الزبائن
  Party? customerByName(String name) {
    final n = name.trim();
    for (final c in customers) {
      if (c.name == n) return c;
    }
    return null;
  }

  Future<int> addCustomer(Party c) async {
    final id = await _repo.addCustomer(c);
    await loadAll();
    return id;
  }

  Future<void> updateCustomer(Party c) async {
    await _repo.updateCustomer(c);
    await loadAll();
  }

  Future<void> deleteCustomer(int id) async {
    await _repo.deleteCustomer(id);
    await loadAll();
  }

  Future<void> addCustomerPayment(PartyPayment p) async {
    await _repo.addCustomerPayment(p);
    await loadAll();
  }

  Future<void> deleteCustomerPayment(int id) async {
    await _repo.deleteCustomerPayment(id);
    await loadAll();
  }

  double paidByCustomer(int id) =>
      customerPayments.where((p) => p.partyId == id).fold(0, (s, p) => s + p.amount);

  // الموردون
  Future<void> addSupplier(Party s) async {
    await _repo.addSupplier(s);
    await loadAll();
  }

  Future<void> updateSupplier(Party s) async {
    await _repo.updateSupplier(s);
    await loadAll();
  }

  Future<void> deleteSupplier(int id) async {
    await _repo.deleteSupplier(id);
    await loadAll();
  }

  Future<void> addSupplierPayment(PartyPayment p) async {
    await _repo.addSupplierPayment(p);
    await loadAll();
  }

  Future<void> deleteSupplierPayment(int id) async {
    await _repo.deleteSupplierPayment(id);
    await loadAll();
  }

  Party? supplierById(int id) {
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<PurchaseInvoice> purchasesOf(int supplierId) =>
      purchases.where((p) => p.supplierId == supplierId).toList();

  /// المتبقي للمورّد = مجموع فواتيره − المدفوع عند الفاتورة − الدفعات اللاحقة.
  double supplierBalance(int supplierId) {
    final bought = purchasesOf(supplierId).fold<double>(0, (s, p) => s + p.total - p.paidAmount);
    final paid = supplierPayments
        .where((p) => p.partyId == supplierId)
        .fold<double>(0, (s, p) => s + p.amount);
    return bought - paid;
  }

  Future<void> addPurchase(PurchaseInvoice p) async {
    await _repo.addPurchase(p);
    await loadAll();
  }

  Future<void> deletePurchase(int id) async {
    await _repo.deletePurchase(id);
    await loadAll();
  }

  // الحجوزات
  Future<void> addReservation(Reservation r) async {
    await _repo.addReservation(r);
    await loadAll();
  }

  Future<void> setReservationStatus(int id, String status) async {
    await _repo.setReservationStatus(id, status);
    await loadAll();
  }

  Future<void> deleteReservation(int id) async {
    await _repo.deleteReservation(id);
    await loadAll();
  }
}
