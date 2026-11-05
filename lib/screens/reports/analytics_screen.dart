import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/analytics.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/invoice.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

/// 📊 تحليلات متقدمة: حركة الأصناف، مقارنة المبيعات والأرباح، وتوقّع احتياج المخزون.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _days = 30; // نافذة تحليل الحركة
  int _cover = 30; // مدة التغطية المطلوبة بالأيام
  String _kind = 'month'; // day | month
  String _base = 'month'; // month | year (الفترة المقارَن بها)

  static const _blue = Color(0xFF2563EB);
  static const _grey = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final invoices = context.watch<InvoiceProvider>().invoices;
    final products = context.watch<ProductProvider>().allProducts;
    final cur = context.watch<SettingsProvider>().currency;

    final flows = Analytics.flows(products, invoices, _days);
    final urgent = Analytics.reorder(Analytics.flows(products, invoices, 30), 14)
        .where((r) => (r.flow.coverDays ?? 0) <= 14)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('التحليلات الذكية')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (urgent.isNotEmpty) _alertBanner(urgent),
          _comparison(invoices, cur),
          _fastMoving(flows),
          _stagnant(flows, cur),
          _reorder(flows),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- تنبيه استباقي

  Widget _alertBanner(List<ReorderSuggestion> urgent) {
    final names = urgent.take(3).map((r) => r.flow.product.name).join('، ');
    return Card(
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${urgent.length} صنف سينفد خلال أسبوعين بمعدل استهلاكه الحالي: $names'
                '${urgent.length > 3 ? ' ...' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- المقارنة

  Widget _comparison(List<Invoice> invoices, String cur) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final months = _base == 'year' ? -12 : -1;
    final tomorrow = today.add(const Duration(days: 1));

    late DateTime curFrom, curTo, baseFrom, baseTo;
    if (_kind == 'day') {
      curFrom = today;
      curTo = tomorrow;
      baseFrom = Analytics.shiftMonths(today, months);
      baseTo = baseFrom.add(const Duration(days: 1));
    } else {
      curFrom = DateTime(today.year, today.month, 1);
      curTo = tomorrow;
      baseFrom = Analytics.shiftMonths(curFrom, months);
      baseTo = Analytics.shiftMonths(today, months).add(const Duration(days: 1));
    }
    final a = Analytics.totals(invoices, curFrom, curTo);
    final b = Analytics.totals(invoices, baseFrom, baseTo);

    final curLabel = _kind == 'day' ? 'اليوم' : 'هذا الشهر (حتى اليوم)';
    final baseLabel = _kind == 'day'
        ? 'نفس اليوم (${Fmt.date(baseFrom)})'
        : '${Fmt.date(baseFrom)} — ${Fmt.date(baseTo.subtract(const Duration(days: 1)))}';

    return _section(
      icon: Icons.compare_arrows,
      title: 'مقارنة المبيعات والأرباح',
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'day', label: Text('اليوم')),
            ButtonSegment(value: 'month', label: Text('الشهر الحالي')),
          ],
          selected: {_kind},
          onSelectionChanged: (v) => setState(() => _kind = v.first),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'month', label: Text('مقابل الشهر السابق')),
            ButtonSegment(value: 'year', label: Text('مقابل السنة السابقة')),
          ],
          selected: {_base},
          onSelectionChanged: (v) => setState(() => _base = v.first),
        ),
        const SizedBox(height: 12),
        _cmpRow('المبيعات', a.sales, b.sales, cur),
        _cmpRow('الأرباح', a.profit, b.profit, cur),
        _cmpRow('عدد الفواتير', a.invoices.toDouble(), b.invoices.toDouble(), '', plain: true),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: (a.sales == 0 && b.sales == 0 && a.profit == 0 && b.profit == 0)
              ? const Center(child: Text('لا توجد مبيعات في الفترتين', style: TextStyle(color: AppColors.grey)))
              : BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(v == 0 ? 'المبيعات' : 'الأرباح',
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    _group(0, a.sales, b.sales),
                    _group(1, a.profit < 0 ? 0 : a.profit, b.profit < 0 ? 0 : b.profit),
                  ],
                )),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 16, children: [
          _legend(_blue, curLabel),
          _legend(_grey, baseLabel),
        ]),
      ],
    );
  }

  BarChartGroupData _group(int x, double cur, double base) => BarChartGroupData(
        x: x,
        barsSpace: 6,
        barRods: [
          BarChartRodData(toY: cur, color: _blue, width: 22, borderRadius: BorderRadius.circular(4)),
          BarChartRodData(toY: base, color: _grey, width: 22, borderRadius: BorderRadius.circular(4)),
        ],
      );

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 11)),
      ]);

  Widget _cmpRow(String label, double now, double base, String cur, {bool plain = false}) {
    final pct = PeriodTotals.change(now, base);
    final up = pct != null && pct >= 0;
    final color = pct == null ? AppColors.grey : (up ? AppColors.success : AppColors.danger);
    String v(double x) => plain ? Fmt.num2(x) : Fmt.money(x, cur);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: const TextStyle(color: AppColors.grey))),
          Expanded(
            child: Text(v(now), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text('كان ${v(base)}', style: const TextStyle(fontSize: 11, color: AppColors.grey)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              pct == null ? '—' : '${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- حركة الأصناف

  Widget _daysChips(int value, ValueChanged<int> onChanged, List<int> options, String suffix) => Wrap(
        spacing: 8,
        children: [
          for (final d in options)
            ChoiceChip(
              label: Text('$d $suffix'),
              selected: value == d,
              onSelected: (_) => onChanged(d),
            ),
        ],
      );

  Widget _fastMoving(List<ProductFlow> flows) {
    final fast = Analytics.fast(flows);
    final maxC = fast.isEmpty ? 1 : fast.first.consumed;
    return _section(
      icon: Icons.local_fire_department,
      title: 'الأصناف الأكثر طلباً',
      children: [
        _daysChips(_days, (d) => setState(() => _days = d), const [30, 60, 90], 'يوم'),
        const SizedBox(height: 8),
        if (fast.isEmpty)
          const Text('لا توجد مبيعات في هذه الفترة', style: TextStyle(color: AppColors.grey)),
        for (var i = 0; i < fast.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${i + 1}. ${fast[i].product.name}', overflow: TextOverflow.ellipsis)),
                    Text('${fast[i].consumed} قطعة',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fast[i].consumed / maxC,
                    minHeight: 6,
                    color: AppColors.success,
                    backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stagnant(List<ProductFlow> flows, String cur) {
    final list = Analytics.stagnant(flows);
    final frozen = list.fold<double>(0, (s, f) => s + f.frozenCapital);
    final now = DateTime.now();
    return _section(
      icon: Icons.ac_unit,
      title: 'الأصناف الراكدة (تجمّد رأس المال)',
      children: [
        if (list.isEmpty)
          const Text('لا توجد أصناف راكدة 👌', style: TextStyle(color: AppColors.grey))
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('رأس مال مجمَّد: ${Fmt.money(frozen, cur)} في ${list.length} صنف',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final f in list.take(15))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(f.product.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                f.consumed == 0
                    ? (f.lastSale == null
                        ? 'لم يُبَع أبداً • المخزون ${f.product.quantity}'
                        : 'لم يُبَع منذ ${now.difference(f.lastSale!).inDays} يوم • المخزون ${f.product.quantity}')
                    : 'بطيء: المخزون ${f.product.quantity} يكفي ${f.coverDays!.round()} يوماً',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(Fmt.money(f.frozenCapital, cur),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (list.length > 15)
            Text('و ${list.length - 15} صنف آخر...', style: const TextStyle(color: AppColors.grey)),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- توقّع الاحتياج

  Widget _reorder(List<ProductFlow> flows) {
    final list = Analytics.reorder(flows, _cover);
    return _section(
      icon: Icons.shopping_cart_checkout,
      title: 'توقّع احتياج المخزون',
      children: [
        const Text('الكمية المقترحة لطلبها من الموردين حسب معدل بيعك الشهري',
            style: TextStyle(fontSize: 12, color: AppColors.grey)),
        const SizedBox(height: 8),
        const Text('أريد تغطية:'),
        _coverChips(),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Text('مخزونك يكفي المدة المحددة لكل الأصناف ✓', style: TextStyle(color: AppColors.success)),
        for (final r in list.take(40))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(r.flow.product.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'يُباع ≈ ${r.flow.perMonth.toStringAsFixed(r.flow.perMonth < 10 ? 1 : 0)} شهرياً • '
              '${r.flow.product.quantity <= 0 ? 'نفد' : 'يكفي ${r.flow.coverDays!.round()} يوماً'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('اطلب ${r.qty}',
                  style: const TextStyle(color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Share.share(_orderText(list)),
              icon: const Icon(Icons.send),
              label: const Text('مشاركة قائمة الطلب (واتساب)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _coverChips() => Wrap(
        spacing: 8,
        children: [
          for (final d in const [15, 30, 60])
            ChoiceChip(
              label: Text(d == 15 ? 'نصف شهر' : (d == 30 ? 'شهر' : 'شهرين')),
              selected: _cover == d,
              onSelected: (_) => setState(() => _cover = d),
            ),
        ],
      );

  String _orderText(List<ReorderSuggestion> list) {
    final b = StringBuffer('قائمة طلب بضاعة (تغطية $_cover يوماً):\n');
    for (final r in list) {
      b.writeln('• ${r.flow.product.name}: ${r.qty}');
    }
    return b.toString();
  }

  Widget _section({required IconData icon, required String title, required List<Widget> children}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
