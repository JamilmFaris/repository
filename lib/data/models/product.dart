class Product {
  final int? id;
  final String name;
  int quantity;
  double buyPrice;
  double sellPrice;
  final DateTime createdAt;

  /// 'SYP' أو 'USD': بالدولار تُحسب buyPrice/sellPrice (بالسوري) من الأسعار بالدولار.
  final String priceMode;
  final double buyPriceUsd;
  final double sellPriceUsd;

  /// عرض «كل offerBuyQty مباعة = offerFreeQty مجاناً» (0 = لا يوجد عرض).
  final int offerBuyQty;
  final int offerFreeQty;

  /// عرض الشركة (تدفع الشركة ثمن الهدية): «كل companyBuyQty = companyFreeQty مجاناً».
  final int companyBuyQty;
  final int companyFreeQty;

  /// تثبيت السعر: 'none' | 'buy' | 'sell' | 'both'، مع سعر الصرف وقت التثبيت.
  final String lockMode;
  final double lockBuyRate;
  final double lockSellRate;

  Product({
    this.id,
    required this.name,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    DateTime? createdAt,
    this.priceMode = 'SYP',
    this.buyPriceUsd = 0,
    this.sellPriceUsd = 0,
    this.offerBuyQty = 0,
    this.offerFreeQty = 0,
    this.companyBuyQty = 0,
    this.companyFreeQty = 0,
    this.lockMode = 'none',
    this.lockBuyRate = 0,
    this.lockSellRate = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUsd => priceMode == 'USD';
  bool get hasOffer => offerBuyQty > 0 && offerFreeQty > 0;
  bool get hasCompanyOffer => companyBuyQty > 0 && companyFreeQty > 0;
  bool get buyLocked => lockMode == 'buy' || lockMode == 'both';
  bool get sellLocked => lockMode == 'sell' || lockMode == 'both';
  bool get isLocked => lockMode != 'none';

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'createdAt': createdAt.toIso8601String(),
    'priceMode': priceMode,
    'buyPriceUsd': buyPriceUsd,
    'sellPriceUsd': sellPriceUsd,
    'offerBuyQty': offerBuyQty,
    'offerFreeQty': offerFreeQty,
    'companyBuyQty': companyBuyQty,
    'companyFreeQty': companyFreeQty,
    'lockMode': lockMode,
    'lockBuyRate': lockBuyRate,
    'lockSellRate': lockSellRate,
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
    createdAt: DateTime.parse(m['createdAt']),
    priceMode: m['priceMode'] ?? 'SYP',
    buyPriceUsd: ((m['buyPriceUsd'] ?? 0) as num).toDouble(),
    sellPriceUsd: ((m['sellPriceUsd'] ?? 0) as num).toDouble(),
    offerBuyQty: m['offerBuyQty'] ?? 0,
    offerFreeQty: m['offerFreeQty'] ?? 0,
    companyBuyQty: m['companyBuyQty'] ?? 0,
    companyFreeQty: m['companyFreeQty'] ?? 0,
    lockMode: m['lockMode'] ?? 'none',
    lockBuyRate: ((m['lockBuyRate'] ?? 0) as num).toDouble(),
    lockSellRate: ((m['lockSellRate'] ?? 0) as num).toDouble(),
  );

  Product copyWith({
    double? buyPrice,
    double? sellPrice,
    double? buyPriceUsd,
    String? lockMode,
    double? lockBuyRate,
    double? lockSellRate,
  }) =>
      Product(
        id: id,
        name: name,
        quantity: quantity,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        createdAt: createdAt,
        priceMode: priceMode,
        buyPriceUsd: buyPriceUsd ?? this.buyPriceUsd,
        sellPriceUsd: sellPriceUsd,
        offerBuyQty: offerBuyQty,
        offerFreeQty: offerFreeQty,
        companyBuyQty: companyBuyQty,
        companyFreeQty: companyFreeQty,
        lockMode: lockMode ?? this.lockMode,
        lockBuyRate: lockBuyRate ?? this.lockBuyRate,
        lockSellRate: lockSellRate ?? this.lockSellRate,
      );

  double get profitPerUnit => sellPrice - buyPrice;
}
