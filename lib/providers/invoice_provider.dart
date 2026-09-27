import 'package:flutter/foundation.dart';
import '../data/models/invoice.dart';
import '../data/repositories/invoice_repository.dart';

class InvoiceProvider extends ChangeNotifier {
  final _repo = InvoiceRepository();
  List<Invoice> _invoices = [];

  List<Invoice> get invoices => _invoices;

  Future<void> loadInvoices() async {
    _invoices = await _repo.getAll();
    notifyListeners();
  }

  Future<String> nextNumber() => _repo.nextNumber();

  Future<void> add(Invoice inv) async {
    await _repo.insert(inv);
    await loadInvoices();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await loadInvoices();
  }

  Invoice? byId(int id) {
    try { return _invoices.firstWhere((i) => i.id == id); } catch (_) { return null; }
  }
}