import 'formatters.dart';

enum PeriodKind { day, week, month, year, all, custom }

/// فترة زمنية [start, end) تُستخدم لتصفية المصاريف والتقارير.
class PeriodRange {
  final PeriodKind kind;
  final DateTime start;
  final DateTime end; // حصري

  const PeriodRange(this.kind, this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  String get label {
    switch (kind) {
      case PeriodKind.day:
        return Fmt.date(start);
      case PeriodKind.week:
        return '${Fmt.date(start)} - ${Fmt.date(end.subtract(const Duration(days: 1)))}';
      case PeriodKind.month:
        return '${start.year}/${start.month.toString().padLeft(2, '0')}';
      case PeriodKind.year:
        return '${start.year}';
      case PeriodKind.all:
        return 'كل الفترات';
      case PeriodKind.custom:
        return '${Fmt.date(start)} - ${Fmt.date(end.subtract(const Duration(days: 1)))}';
    }
  }

  /// فترة من نوع معيّن حول تاريخ مرجعي. الأسبوع يبدأ يوم السبت.
  static PeriodRange of(PeriodKind kind, DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    switch (kind) {
      case PeriodKind.day:
        return PeriodRange(kind, d, d.add(const Duration(days: 1)));
      case PeriodKind.week:
        final back = (d.weekday - DateTime.saturday) % 7;
        final s = d.subtract(Duration(days: back));
        return PeriodRange(kind, s, s.add(const Duration(days: 7)));
      case PeriodKind.month:
        return PeriodRange(kind, DateTime(d.year, d.month), DateTime(d.year, d.month + 1));
      case PeriodKind.year:
        return PeriodRange(kind, DateTime(d.year), DateTime(d.year + 1));
      case PeriodKind.all:
      case PeriodKind.custom:
        return PeriodRange(PeriodKind.all, DateTime(2000), DateTime(2200));
    }
  }
}
