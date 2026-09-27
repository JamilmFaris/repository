import 'invoice_item.dart';

class Invoice {
  final int? id;
  final String number;
  final String customerName;
  final DateTime date;
  final List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.number,
    required this.customerName,
    required this.date,
    required this.items,
  });

  double get total => items.fold(0, (s, i) => s + i.totalSell);
  double get totalCost => items.fold(0, (s, i) => s + i.totalBuy);
  double get totalProfit => total - totalCost;

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'customerName': customerName,
    'date': date.toIso8601String(),
  };

  factory Invoice.fromMap(Map<String, dynamic> m, List<InvoiceItem> items) => Invoice(
    id: m['id'],
    number: m['number'],
    customerName: m['customerName'],
    date: DateTime.parse(m['date']),
    items: items,
  );
}