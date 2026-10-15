import 'package:flutter/foundation.dart';
import '../core/utils/pricing.dart';
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

  /// أصناف وصلت للحد الأدنى (أكبر من 0 وأقل من أو تساوي الحد).
  List<Product> lowStockFor(int threshold) =>
      _products.where((p) => p.quantity > 0 && p.quantity <= threshold).toList();
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

  /// إعادة تسعير أصناف الدولار عند تغيّر سعر الصرف: الشراء بسعر شراء الدولار،
  /// والمبيع بسعر بيع الدولار، مع احترام السعر المثبَّت (لا يتغيّر).
  Future<void> repriceAll(double buyRate, double sellRate) async {
    for (final p in _products.where((p) => p.isUsd)) {
      await _repo.update(_repriced(p, buyRate, sellRate));
    }
    await loadProducts();
  }

  Product _repriced(Product p, double buyRate, double sellRate) => p.copyWith(
        buyPrice: p.buyLocked || buyRate <= 0
            ? p.buyPrice
            : Pricing.usdToSyp(p.buyPriceUsd, buyRate),
        sellPrice: p.sellLocked || sellRate <= 0
            ? p.sellPrice
            : Pricing.usdToSyp(p.sellPriceUsd, sellRate),
      );

  /// تفعيل تثبيت السعر (شراء/بيع/كليهما) وحفظ سعر الصرف الحالي داخل الصنف.
  Future<void> setLock(Product p, String mode, double buyRate, double sellRate) async {
    await _repo.update(p.copyWith(
      lockMode: mode,
      lockBuyRate: buyRate,
      lockSellRate: sellRate,
    ));
    await loadProducts();
  }

  /// إلغاء التثبيت: يعود الصنف لمتابعة سعر الصرف الحالي فوراً.
  Future<void> unlock(Product p, double buyRate, double sellRate) async {
    final unlocked = p.copyWith(lockMode: 'none', lockBuyRate: 0, lockSellRate: 0);
    await _repo.update(_repriced(unlocked, buyRate, sellRate));
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