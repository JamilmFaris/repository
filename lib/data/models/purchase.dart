class PurchaseItem {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;

  /// سعر الشراء بالسوري (يُخزَّن في الفاتورة).
  final double buyPrice;

  /// سعر الشراء بالدولار إن كان الصنف مسعّراً بالدولار (لا يُخزَّن، لتحديث الصنف فقط).
  final double? usdPrice;

  /// عدد قطع هدية الشركة ضمن [quantity] (السعر المخزَّن موزّع على كل القطع).
  final int giftQty;

  /// حصّة هذا السطر من الشحن والجمارك (بالسوري، إجمالي السطر). لا تدخل في دَين المورّد.
  final double extraCost;

  /// سعر الشراء الفعلي بالدولار شاملاً الحصّة (للأصناف المسعّرة بالدولار فقط).
  final double? landedUsd;

  PurchaseItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.buyPrice,
    this.usdPrice,
    this.giftQty = 0,
    this.extraCost = 0,
    this.landedUsd,
  });

  double get total => buyPrice * quantity;

  /// تكلفة القطعة الفعلية شاملة الشحن والجمارك.
  double get landedUnit => quantity == 0 ? buyPrice : buyPrice + extraCost / quantity;

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'giftQty': giftQty,
    'extraCost': extraCost,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
    id: m['id'],
    productId: m['productId'],
    productName: m['productName'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
    giftQty: m['giftQty'] ?? 0,
    extraCost: ((m['extraCost'] ?? 0) as num).toDouble(),
  );
}

class PurchaseInvoice {
  final int? id;
  final int supplierId;
  final String number;
  final DateTime date;
  final double paidAmount;
  final String notes;
  final List<PurchaseItem> items;

  /// الشحن والمصاريف الإضافية (بالسوري): تُدفع لجهة أخرى نقداً وتدخل في تكلفة القطع فقط.
  final double shippingCost;
  final double otherCost;

  PurchaseInvoice({
    this.id,
    required this.supplierId,
    this.number = '',
    required this.date,
    this.paidAmount = 0,
    this.notes = '',
    required this.items,
    this.shippingCost = 0,
    this.otherCost = 0,
  });

  double get extraTotal => shippingCost + otherCost;

  double get total => items.fold(0, (s, i) => s + i.total);
  double get remaining => total - paidAmount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplierId': supplierId,
    'number': number,
    'date': date.toIso8601String(),
    'paidAmount': paidAmount,
    'notes': notes,
    'shippingCost': shippingCost,
    'otherCost': otherCost,
  };

  factory PurchaseInvoice.fromMap(Map<String, dynamic> m, List<PurchaseItem> items) =>
      PurchaseInvoice(
        id: m['id'],
        supplierId: m['supplierId'],
        number: m['number'] ?? '',
        date: DateTime.parse(m['date']),
        paidAmount: (m['paidAmount'] as num).toDouble(),
        notes: m['notes'] ?? '',
        items: items,
        shippingCost: ((m['shippingCost'] ?? 0) as num).toDouble(),
        otherCost: ((m['otherCost'] ?? 0) as num).toDouble(),
      );
}

/// مرتجع بضاعة إلى مورّد.
class SupplierReturn {
  final int? id;
  final int supplierId;
  final DateTime date;
  final String reason;
  final String note;
  final List<SupplierReturnItem> items;

  SupplierReturn({
    this.id,
    required this.supplierId,
    required this.date,
    this.reason = '',
    this.note = '',
    required this.items,
  });

  double get total => items.fold(0, (s, i) => s + i.total);
}

class SupplierReturnItem {
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  SupplierReturnItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });
  double get total => quantity * unitPrice;
}
