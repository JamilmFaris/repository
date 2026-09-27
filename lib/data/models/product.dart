class Product {
  final int? id;
  final String name;
  int quantity;
  double buyPrice;
  double sellPrice;
  final DateTime createdAt;

  Product({
    this.id,
    required this.name,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
    createdAt: DateTime.parse(m['createdAt']),
  );

  double get profitPerUnit => sellPrice - buyPrice;
}