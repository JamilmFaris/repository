class Coupon {
  final int? id;
  final String code;

  /// 'percent' | 'amount'
  final String type;
  final double value;
  final DateTime? expiry;
  final bool active;

  Coupon({
    this.id,
    required this.code,
    required this.type,
    required this.value,
    this.expiry,
    this.active = true,
  });

  bool get isExpired =>
      expiry != null && DateTime.now().isAfter(DateTime(expiry!.year, expiry!.month, expiry!.day, 23, 59, 59));

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'type': type,
    'value': value,
    'expiry': expiry?.toIso8601String(),
    'active': active ? 1 : 0,
  };

  factory Coupon.fromMap(Map<String, dynamic> m) => Coupon(
    id: m['id'],
    code: m['code'],
    type: m['type'],
    value: (m['value'] as num).toDouble(),
    expiry: m['expiry'] == null ? null : DateTime.parse(m['expiry']),
    active: (m['active'] ?? 1) == 1,
  );
}
