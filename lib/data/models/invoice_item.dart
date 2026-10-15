class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  int quantity;
  final double buyPrice;
  final double sellPrice;

  /// 'none' | 'percent' | 'amount'
  String discountType;
  double discountValue;

  /// سطر هدية (عرض): سعره 0 وتكلفته تُسجَّل في مصاريف «العروض».
  final bool isGift;

  /// نوع الهدية: 'mine' (على حسابي: تكلفتها مصروف) | 'company' (تدفعها الشركة: مجانية).
  final String giftType;
  int returnedQty;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    this.discountType = 'none',
    this.discountValue = 0,
    this.isGift = false,
    this.giftType = 'mine',
    this.returnedQty = 0,
  });

  /// الكمية المتبقية بعد المرتجعات.
  int get keptQty => quantity - returnedQty;

  /// الكمية المباعة بسعر (بدون الهدايا والمرتجع).
  int get soldQty => isGift ? 0 : keptQty;

  double get gross => sellPrice * quantity;

  double get discountAmount {
    if (isGift) return 0;
    switch (discountType) {
      case 'percent':
        return (gross * discountValue / 100).clamp(0, gross).toDouble();
      case 'amount':
        return discountValue.clamp(0, gross).toDouble();
      default:
        return 0;
    }
  }

  /// صافي قيمة السطر بعد خصم الصنف (قبل المرتجع).
  double get netSell => gross - discountAmount;

  /// قيمة السطر الباقية بعد خصم الصنف والمرتجع.
  double get totalSell => quantity == 0 ? 0 : netSell * keptQty / quantity;

  /// تكلفة الأصناف المباعة (الهدايا تكلفتها في المصاريف لا هنا).
  double get totalBuy => isGift ? 0 : buyPrice * keptQty;

  bool get isCompanyGift => isGift && giftType == 'company';
  bool get isMyGift => isGift && giftType != 'company';

  /// تكلفة هديتي الشخصية فقط (تذهب لمصاريف «العروض»)؛ هدايا الشركة مجانية.
  double get giftCost => isMyGift ? buyPrice * keptQty : 0;

  double get profit => totalSell - totalBuy;

  Map<String, dynamic> toMap() => {
    'id': id,
    'invoiceId': invoiceId,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'discountType': discountType,
    'discountValue': discountValue,
    'isGift': isGift ? 1 : 0,
    'giftType': giftType,
    'returnedQty': returnedQty,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
    id: m['id'],
    invoiceId: m['invoiceId'],
    productId: m['productId'],
    productName: m['productName'],
    quantity: m['quantity'],
    buyPrice: (m['buyPrice'] as num).toDouble(),
    sellPrice: (m['sellPrice'] as num).toDouble(),
    discountType: m['discountType'] ?? 'none',
    discountValue: ((m['discountValue'] ?? 0) as num).toDouble(),
    isGift: (m['isGift'] ?? 0) == 1,
    giftType: m['giftType'] ?? 'mine',
    returnedQty: m['returnedQty'] ?? 0,
  );
}
