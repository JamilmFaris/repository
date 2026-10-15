/// وصل استلام مبلغ من زبون (يُسجَّل معه دفعة تُنقص دَينه).
class Receipt {
  final int? id;
  final int number;
  final int? customerId;
  final String customerName;
  final double amount;
  final String purpose;
  final String note;
  final DateTime date;
  final int? paymentId;

  Receipt({
    this.id,
    required this.number,
    this.customerId,
    required this.customerName,
    required this.amount,
    this.purpose = '',
    this.note = '',
    required this.date,
    this.paymentId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'customerName': customerName,
    'amount': amount,
    'purpose': purpose,
    'note': note,
    'date': date.toIso8601String(),
    'paymentId': paymentId,
  };

  factory Receipt.fromMap(Map<String, dynamic> m) => Receipt(
    id: m['id'],
    number: m['number'],
    customerId: m['customerId'],
    customerName: m['customerName'],
    amount: (m['amount'] as num).toDouble(),
    purpose: m['purpose'] ?? '',
    note: m['note'] ?? '',
    date: DateTime.parse(m['date']),
    paymentId: m['paymentId'],
  );
}
