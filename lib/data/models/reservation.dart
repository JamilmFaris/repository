class ReservationItem {
  final int productId;
  final String productName;
  final int quantity;
  ReservationItem({required this.productId, required this.productName, required this.quantity});
}

class Reservation {
  final int? id;
  final String customerName;
  final DateTime date;
  final DateTime? dueDate;
  final String notes;

  /// 'open' | 'done' | 'cancelled'
  final String status;
  final List<ReservationItem> items;

  Reservation({
    this.id,
    required this.customerName,
    required this.date,
    this.dueDate,
    this.notes = '',
    this.status = 'open',
    required this.items,
  });
}
