class PurchaseItem {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;

  /// سعر الشراء بالسوري (يُخزَّن في الفاتورة).
  final double buyPrice;

  /// سعر الشراء بالدولار إن كان الصنف مسعّراً بالدولار (لا يُخزَّن، لتحديث الصنف فقط).
  final double? usdPrice;

  PurchaseItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.buyPrice,
    this.usdPrice,
  });

  double get total => buyPrice * quantity;

  Map<String, dynamic> toMap() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'buyPrice': buyPrice,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
    id: m['id'],
    productId: m['productId'],
    productName: m['productName'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
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

  PurchaseInvoice({
    this.id,
    required this.supplierId,
    this.number = '',
    required this.date,
    this.paidAmount = 0,
    this.notes = '',
    required this.items,
  });

  double get total => items.fold(0, (s, i) => s + i.total);
  double get remaining => total - paidAmount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'supplierId': supplierId,
    'number': number,
    'date': date.toIso8601String(),
    'paidAmount': paidAmount,
    'notes': notes,
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
      );
}
