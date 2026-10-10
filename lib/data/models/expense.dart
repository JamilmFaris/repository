class Expense {
  final int? id;
  final String category;
  final double amount;
  final String description;
  final DateTime date;

  /// مصروف «العروض» التلقائي مرتبط بفاتورة (لا يُعدَّل يدوياً).
  final int? invoiceId;

  Expense({
    this.id,
    required this.category,
    required this.amount,
    this.description = '',
    required this.date,
    this.invoiceId,
  });

  bool get isAuto => invoiceId != null;

  /// تصنيفات المصاريف المتاحة للإدخال اليدوي.
  static const manualCategories = [
    'أكياس وتغليف',
    'نقل وتوصيل',
    'عمال وأجور',
    'صيانة',
    'فواتير',
    'إيجار',
    'أخرى',
  ];

  static const giftCategory = 'العروض';

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'amount': amount,
    'description': description,
    'date': date.toIso8601String(),
    'invoiceId': invoiceId,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'],
    category: m['category'],
    amount: (m['amount'] as num).toDouble(),
    description: m['description'] ?? '',
    date: DateTime.parse(m['date']),
    invoiceId: m['invoiceId'],
  );
}
