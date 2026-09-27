class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final int quantity;
  final double buyPrice;
  final double sellPrice;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
  });

  double get totalSell => sellPrice * quantity;
  double get totalBuy => buyPrice * quantity;
  double get profit => totalSell - totalBuy;

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceId': invoiceId,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
    id: m['id'],
    invoiceId: m['invoiceId'],
    productId: m['productId'],
    productName: m['productName'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
  );
}