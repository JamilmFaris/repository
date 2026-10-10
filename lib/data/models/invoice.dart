import 'invoice_item.dart';

class Invoice {
  final int? id;
  String number;
  String customerName;
  DateTime date;
  String notes;
  List<InvoiceItem> items;

  /// خصم الفاتورة: 'none' | 'percent' | 'amount'، وقد يأتي من كوبون.
  String discountType;
  double discountValue;
  String? couponCode;

  /// ربط بالزبون (اختياري) والمبلغ المدفوع وقت البيع؛ null = مدفوعة بالكامل.
  int? customerId;
  double? paidAmount;

  Invoice({
    this.id,
    required this.number,
    required this.customerName,
    required this.date,
    this.notes = '',
    required this.items,
    this.discountType = 'none',
    this.discountValue = 0,
    this.couponCode,
    this.customerId,
    this.paidAmount,
  });

  /// مجموع الأصناف بعد خصم الأصناف والمرتجع (قبل خصم الفاتورة).
  double get subtotal => items.fold(0, (s, i) => s + i.totalSell);

  double get itemsDiscount => items.fold(0, (s, i) => s + i.discountAmount);

  double get invoiceDiscount {
    final base = subtotal;
    switch (discountType) {
      case 'percent':
        return (base * discountValue / 100).clamp(0, base).toDouble();
      case 'amount':
        return discountValue.clamp(0, base).toDouble();
      default:
        return 0;
    }
  }

  /// المجموع الكلي قبل أي خصم (أصناف وفاتورة)، بعد استبعاد المرتجع.
  double get grossTotal => items.fold(
      0, (s, i) => s + (i.quantity == 0 ? 0 : i.gross * i.keptQty / i.quantity));

  /// إجمالي الخصم (خصومات الأصناف + خصم الفاتورة).
  double get totalDiscount => grossTotal - total;

  double get total => subtotal - invoiceDiscount;

  /// المتبقي على الزبون من هذه الفاتورة (دين). المرتجع يُنقِص الإجمالي فيُنقِص الدين.
  double get owed {
    final paid = paidAmount;
    if (paid == null) return 0;
    final v = total - paid;
    return v > 0 ? v : 0;
  }

  double get totalCost => items.fold(0, (s, i) => s + i.totalBuy);
  double get giftCost => items.fold(0, (s, i) => s + i.giftCost);
  double get totalProfit => total - totalCost;

  /// قيمة السطر بعد توزيع خصم الفاتورة بالتناسب.
  double netOf(InvoiceItem it) {
    final sub = subtotal;
    return sub == 0 ? 0 : it.totalSell * total / sub;
  }

  double profitOf(InvoiceItem it) => netOf(it) - it.totalBuy;

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'customerName': customerName,
    'date': date.toIso8601String(),
    'notes': notes,
    'discountType': discountType,
    'discountValue': discountValue,
    'couponCode': couponCode,
    'customerId': customerId,
    'paidAmount': paidAmount,
  };

  factory Invoice.fromMap(Map<String, dynamic> m, List<InvoiceItem> items) => Invoice(
    id: m['id'],
    number: m['number'],
    customerName: m['customerName'],
    date: DateTime.parse(m['date']),
    notes: m['notes'] ?? '',
    items: items,
    discountType: m['discountType'] ?? 'none',
    discountValue: ((m['discountValue'] ?? 0) as num).toDouble(),
    couponCode: m['couponCode'],
    customerId: m['customerId'],
    paidAmount: (m['paidAmount'] as num?)?.toDouble(),
  );
}
