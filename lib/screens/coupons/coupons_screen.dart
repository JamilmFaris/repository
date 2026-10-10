import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/coupon.dart';
import '../../data/repositories/coupon_repository.dart';
import '../../widgets/empty_state.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});
  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final _repo = CouponRepository();
  List<Coupon> _coupons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _repo.getAll();
    if (mounted) setState(() => _coupons = c);
  }

  Future<void> _add() async {
    final code = TextEditingController();
    final value = TextEditingController();
    var type = 'percent';
    DateTime? expiry;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('كوبون جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'الرمز', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'percent', label: Text('نسبة %')),
                    ButtonSegment(value: 'amount', label: Text('مبلغ')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setD(() => type = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  onTap: () => Fmt.selectAll(value),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: type == 'percent' ? 'نسبة الخصم %' : 'مبلغ الخصم',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(expiry == null ? 'تاريخ الانتهاء (اختياري)' : Fmt.date(expiry!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setD(() => expiry = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final v = Fmt.parseNum(value.text) ?? 0;
    if (ok != true || code.text.trim().isEmpty || v <= 0) return;
    try {
      await _repo.insert(Coupon(code: code.text.trim(), type: type, value: v, expiry: expiry));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('هذا الرمز مستخدم من قبل')));
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكوبونات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('كوبون جديد'),
      ),
      body: _coupons.isEmpty
          ? const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'لا توجد كوبونات',
              subtitle: 'أنشئ كوبوناً ثم أدخل رمزه عند إنشاء الفاتورة')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: _coupons.length,
              itemBuilder: (_, i) {
                final c = _coupons[i];
                final val = c.type == 'percent' ? '${Fmt.num2(c.value)}%' : Fmt.num2(c.value);
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.local_offer, color: Theme.of(context).colorScheme.primary),
                    title: Text('${c.code} — خصم $val',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.expiry == null
                        ? 'بدون انتهاء'
                        : (c.isExpired ? 'منتهي ' : 'ينتهي ') + Fmt.date(c.expiry!)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: c.active,
                          onChanged: (v) async {
                            await _repo.setActive(c.id!, v);
                            await _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.danger),
                          onPressed: () async {
                            await _repo.delete(c.id!);
                            await _load();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
