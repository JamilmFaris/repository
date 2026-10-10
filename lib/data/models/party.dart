/// زبون أو مورّد (نفس الحقول).
class Party {
  final int? id;
  final String name;
  final String phone;
  final String notes;
  final DateTime createdAt;

  Party({this.id, required this.name, this.phone = '', this.notes = '', DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Party.fromMap(Map<String, dynamic> m) => Party(
    id: m['id'],
    name: m['name'],
    phone: m['phone'] ?? '',
    notes: m['notes'] ?? '',
    createdAt: DateTime.parse(m['createdAt']),
  );
}

/// دفعة من زبون (تسديد دين) أو إلى مورّد.
class PartyPayment {
  final int? id;
  final int partyId;
  final int? refId; // فاتورة بيع/شراء مرتبطة (اختياري)
  final double amount;
  final DateTime date;
  final String note;

  PartyPayment({
    this.id,
    required this.partyId,
    this.refId,
    required this.amount,
    required this.date,
    this.note = '',
  });
}
