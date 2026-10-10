import 'package:flutter/foundation.dart';
import '../data/models/invoice.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final _repo = InvoiceRepository();
  List<Invoice> _invoices = [];
  Map<int, double> _refunds = {};

  List<Invoice> get invoices => _invoices;

  /// مجموع المبالغ المسترجعة لفاتورة (مرتجعات).
  double refundOf(int invoiceId) => _refunds[invoiceId] ?? 0;

  Future<void> loadInvoices() async {
    _invoices = await _repo.getAll();
    _refunds = await _repo.refundsByInvoice();
    notifyListeners();
  }

  Future<String> nextNumber() => _repo.nextNumber();
  Future<bool> numberExists(String n, {int? exceptId}) =>
      _repo.numberExists(n, exceptId: exceptId);

  /// الحفظ والتعديل والحذف والمرتجع تعدّل المخزون داخل المستودع؛
  /// على الشاشة إعادة تحميل الأصناف بعدها.
  Future<void> add(Invoice inv) async {
    await _repo.insert(inv);
    await loadInvoices();
  }

  Future<void> update(Invoice inv) async {
    await _repo.update(inv);
    await loadInvoices();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await loadInvoices();
  }

  Future<void> returnItems(int invoiceId, List<ReturnLine> lines) async {
    await _repo.returnItems(invoiceId, lines);
    await loadInvoices();
  }

  Invoice? byId(int id) {
    try { return _invoices.firstWhere((i) => i.id == id); } catch (_) { return null; }
  }
}
