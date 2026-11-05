import '../../data/models/invoice.dart';
import '../../data/models/product.dart';

/// حركة صنف واحد خلال نافذة زمنية.
class ProductFlow {
  final Product product;

  /// المستهلك من المخزون (المباع + الهدايا، صافي المرتجع).
  final int consumed;

  /// المباع بسعر فقط (بدون الهدايا).
  final int sold;
  final double revenue;
  final DateTime? lastSale;

  /// عدد الأيام الفعلية المستخدمة في حساب المعدل.
  final int windowDays;

  ProductFlow(this.product, this.consumed, this.sold, this.revenue, this.lastSale, this.windowDays);

  /// معدل الاستهلاك اليومي.
  double get perDay => windowDays == 0 ? 0 : consumed / windowDays;
  double get perMonth => perDay * 30;

  /// كم يوماً يكفي المخزون الحالي بهذا المعدل (null = لا استهلاك).
  double? get coverDays => perDay <= 0 ? null : product.quantity / perDay;

  /// رأس المال المجمَّد في المخزون (القطع المدفوعة فقط × سعر الشراء).
  double get frozenCapital => product.buyPrice * product.paidQuantity;
}

class ReorderSuggestion {
  final ProductFlow flow;
  final int qty;
  ReorderSuggestion(this.flow, this.qty);
}

class PeriodTotals {
  final double sales;
  final double profit;
  final int invoices;
  const PeriodTotals(this.sales, this.profit, this.invoices);

  /// نسبة التغيّر عن [base] (null إن لم يوجد أساس للمقارنة).
  static double? change(double now, double base) => base == 0 ? null : (now - base) / base * 100;
}

class Analytics {
  /// تحليل حركة كل الأصناف خلال آخر [days] يوماً (النافذة تُقصَّر إن كان عمر البيانات أقل).
  static List<ProductFlow> flows(
    List<Product> products,
    List<Invoice> invoices,
    int days, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final from = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final inWindow = invoices.where((i) => !i.date.isBefore(from) && !i.date.isAfter(today));

    // عمر البيانات: لا نقسم على 30 يوماً إن كان أول بيع قبل أسبوعين فقط
    var effective = days;
    if (invoices.isNotEmpty) {
      final first = invoices.map((i) => i.date).reduce((a, b) => a.isBefore(b) ? a : b);
      final age = today.difference(first).inDays + 1;
      effective = age.clamp(7, days);
    }

    final consumed = <int, int>{};
    final sold = <int, int>{};
    final revenue = <int, double>{};
    for (final inv in inWindow) {
      for (final it in inv.items) {
        consumed[it.productId] = (consumed[it.productId] ?? 0) + it.keptQty;
        if (!it.isGift) {
          sold[it.productId] = (sold[it.productId] ?? 0) + it.soldQty;
          revenue[it.productId] = (revenue[it.productId] ?? 0) + inv.netOf(it);
        }
      }
    }
    // آخر بيع لكل صنف (على كل التاريخ، لعرض «لم يُبع منذ N يوم»)
    final last = <int, DateTime>{};
    for (final inv in invoices) {
      for (final it in inv.items) {
        if (it.isGift || it.keptQty <= 0) continue;
        final d = last[it.productId];
        if (d == null || inv.date.isAfter(d)) last[it.productId] = inv.date;
      }
    }

    return [
      for (final p in products)
        ProductFlow(p, consumed[p.id] ?? 0, sold[p.id] ?? 0, revenue[p.id] ?? 0, last[p.id], effective),
    ];
  }

  /// الأكثر طلباً: الأعلى استهلاكاً.
  static List<ProductFlow> fast(List<ProductFlow> f, [int n = 10]) {
    final l = f.where((x) => x.consumed > 0).toList()
      ..sort((a, b) => b.consumed.compareTo(a.consumed));
    return l.take(n).toList();
  }

  /// الراكدة: لها مخزون ولم تُبَع خلال النافذة، أو مخزونها يكفي أكثر من [slowCoverDays] يوماً.
  /// مرتّبة بحسب رأس المال المجمَّد (الأكبر أولاً).
  static List<ProductFlow> stagnant(List<ProductFlow> f, {int slowCoverDays = 180}) {
    final l = f.where((x) {
      if (x.product.quantity <= 0) return false;
      if (x.consumed == 0) return true;
      final c = x.coverDays;
      return c != null && c > slowCoverDays;
    }).toList()
      ..sort((a, b) => b.frozenCapital.compareTo(a.frozenCapital));
    return l;
  }

  /// اقتراحات الطلب: الأصناف التي لا يكفي مخزونها [coverDays] يوماً بمعدل استهلاكها.
  /// الكمية المقترحة = الاحتياج خلال المدة − المتوفر. الأقرب للنفاد أولاً.
  static List<ReorderSuggestion> reorder(List<ProductFlow> f, int coverDays) {
    final out = <ReorderSuggestion>[];
    for (final x in f) {
      if (x.consumed <= 0) continue;
      final need = (x.perDay * coverDays).ceil() - x.product.quantity;
      if (need > 0) out.add(ReorderSuggestion(x, need));
    }
    out.sort((a, b) =>
        (a.flow.coverDays ?? 0).compareTo(b.flow.coverDays ?? 0));
    return out;
  }

  static PeriodTotals totals(List<Invoice> invoices, DateTime from, DateTime toExclusive) {
    var sales = 0.0, profit = 0.0, n = 0;
    for (final i in invoices) {
      if (i.date.isBefore(from) || !i.date.isBefore(toExclusive)) continue;
      sales += i.total;
      profit += i.totalProfit;
      n++;
    }
    return PeriodTotals(sales, profit, n);
  }

  /// يزيح تاريخاً بعدد أشهر مع الحفاظ على اليوم (أو آخر يوم في الشهر إن لم يوجد).
  static DateTime shiftMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }
}
