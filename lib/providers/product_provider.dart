import 'package:flutter/foundation.dart';
import '../data/models/product.dart';
import '../data/repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  final _repo = ProductRepository();
  List<Product> _products = [];
  String _search = '';
  String _sortBy = 'name';

  List<Product> get products {
    var list = List<Product>.from(_products);
    if (_search.isNotEmpty) {
      list = list.where((p) => p.name.contains(_search)).toList();
    }
    switch (_sortBy) {
      case 'quantity': list.sort((a, b) => a.quantity.compareTo(b.quantity)); break;
      case 'name': list.sort((a, b) => a.name.compareTo(b.name)); break;
    }
    return list;
  }

  List<Product> get lowStock => _products.where((p) => p.quantity > 0 && p.quantity <= 5).toList();
  List<Product> get outOfStock => _products.where((p) => p.quantity <= 0).toList();

  void setSearch(String v) { _search = v; notifyListeners(); }
  void setSort(String v) { _sortBy = v; notifyListeners(); }

  Future<void> loadProducts() async {
    _products = await _repo.getAll();
    notifyListeners();
  }

  Future<void> add(Product p) async {
    await _repo.insert(p);
    await loadProducts();
  }

  Future<void> update(Product p) async {
    await _repo.update(p);
    await loadProducts();
  }

  Future<void> updateQuantity(Product p, int qty) async {
    p.quantity = qty;
    await _repo.update(p);
    await loadProducts();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await loadProducts();
  }

  Product? byId(int id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}