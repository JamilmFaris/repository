import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/backup_service.dart';
import '../../providers/cash_provider.dart';
import '../../providers/expense_provider.dart';
import '../../data/database/database_helper.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/capital.dart';
import '../coupons/coupons_screen.dart';
import '../products/add_edit_product_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _address;
  late TextEditingController _currency;
  late TextEditingController _rate;
  late TextEditingController _buyRate;
  late TextEditingController _rep;
  late TextEditingController _dist;
  late TextEditingController _low;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _name = TextEditingController(text: s.storeName);
    _phone = TextEditingController(text: s.phone);
    _address = TextEditingController(text: s.address);
    _currency = TextEditingController(text: s.currency);
    _rate = TextEditingController(text: _plain(s.dollarRate));
    _buyRate = TextEditingController(text: _plain(s.dollarBuyRate));
    _rep = TextEditingController(text: s.repPhone);
    _dist = TextEditingController(text: s.distPhone);
    _low = TextEditingController(text: '${s.lowStock}');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    _rate.dispose();
    _buyRate.dispose();
    _rep.dispose();
    _dist.dispose();
    _low.dispose();
    super.dispose();
  }

  String _plain(double v) =>
      v <= 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final products = context.watch<ProductProvider>().products;
    final locked = products.where((p) => p.isLocked).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('معلومات المتجر',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _field(_name, 'اسم المتجر', Icons.store),
          _field(_phone, 'رقم صاحب التطبيق (يظهر في الفاتورة)', Icons.phone),
          _field(_address, 'العنوان', Icons.location_on),
          _field(_currency, 'العملة', Icons.monetization_on),
          _field(_rep, 'رقم المندوب (اختياري)', Icons.person_pin, phone: true),
          _field(_dist, 'رقم الموزع (اختياري)', Icons.local_shipping, phone: true),
          _headerPreview(),
          const SizedBox(height: 12),
          _field(_buyRate, 'سعر شراء الدولار (لتقييم رأس المال وأسعار الشراء)', Icons.attach_money, number: true),
          _field(_rate, 'سعر بيع الدولار (لأسعار المبيع والربح بالدولار)', Icons.attach_money, number: true),
          _field(_low, 'حد تنبيه المخزون المنخفض (عدد القطع)', Icons.warning_amber, number: true),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final rate = Fmt.parseNum(_rate.text) ?? 0;
                var buyRate = Fmt.parseNum(_buyRate.text) ?? 0;
                if (buyRate <= 0) buyRate = rate; // سعر واحد إن لم يُحدَّد سعر الشراء
                final changed = rate != s.dollarRate || buyRate != s.dollarBuyRate;
                final prodProv = context.read<ProductProvider>();
                await s.update(
                  storeName: _name.text,
                  phone: _phone.text,
                  address: _address.text,
                  currency: _currency.text,
                  dollarRate: rate,
                  dollarBuyRate: buyRate,
                  repPhone: _rep.text.trim(),
                  distPhone: _dist.text.trim(),
                  lowStock: (Fmt.parseNum(_low.text) ?? 5).toInt().clamp(0, 100000),
                );
                // تغيّر الصرف لا يُعدّ ربحاً: الأصناف المسعّرة بالدولار تُعاد تسعيرتها
                // والمثبّتة تبقى (رأس المال بالليرة يُشتقّ من رأسمال الدولار × السعر الجديد)
                if (changed && rate > 0) await prodProv.repriceAll(buyRate, rate);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ المعلومات بنجاح')),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('حفظ المعلومات', style: TextStyle(fontSize: 16)),
            ),
          ),
          const Divider(height: 32),
          const Text('المظهر',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SwitchListTile(
            value: s.isDarkMode,
            onChanged: s.toggleDark,
            title: const Text('الوضع الليلي'),
            secondary: const Icon(Icons.dark_mode),
          ),
          const SizedBox(height: 8),
          const Text('نمط التطبيق'),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: s.appStyle,
            onChanged: (v) => s.setAppStyle(v!),
            child: const Column(
              children: [
                RadioListTile<String>(
                  value: 'normal',
                  title: Text('عادي'),
                  subtitle: Text('لونك المختار + الوضع الليلي'),
                ),
                RadioListTile<String>(
                  value: 'luxury',
                  title: Text('فاخر (ذهبي وأسود)'),
                ),
                RadioListTile<String>(
                  value: 'calm',
                  title: Text('هادئ (أخضر وأبيض) للعمل اليومي'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('لون التطبيق (للنمط العادي)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () => s.setThemeColor(c.toARGB32()),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: c,
                    child: s.themeColor == c.toARGB32()
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
          const Divider(height: 32),
          const Text('رأس المال المرجعي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            s.refCapitalUsd > 0
                ? 'المثبّت: \$${Fmt.num2(s.refCapitalUsd)} (بسعر ${Fmt.num2(s.refCapitalRate)}) '
                    'بتاريخ ${s.refCapitalDate == null ? '-' : Fmt.date(s.refCapitalDate!)}'
                : 'لم يُثبَّت رأس مال مرجعي بعد',
            style: const TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('تثبيت رأس المال الحالي'),
            onPressed: _pinCapital,
          ),
          const Divider(height: 32),
          const Row(children: [
            Icon(Icons.lock, size: 18),
            SizedBox(width: 6),
            Text('الأصناف المثبّتة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          if (locked.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لا توجد أصناف مثبّتة السعر', style: TextStyle(color: AppColors.grey)),
            ),
          for (final p in locked)
            Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text(
                    'تثبيت ${p.lockMode == 'buy' ? 'الشراء' : (p.lockMode == 'sell' ? 'البيع' : 'الشراء والبيع')}'),
                trailing: Wrap(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p)),
                      ),
                      child: const Text('الذهاب للصنف'),
                    ),
                    TextButton(
                      onPressed: () => context
                          .read<ProductProvider>()
                          .unlock(p, s.dollarBuyRate, s.dollarRate),
                      child: const Text('إلغاء التثبيت'),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: const Text('الكوبونات'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CouponsScreen())),
          ),
          const Divider(height: 32),
          const Text('النسخ الاحتياطي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('تصدير نسخة احتياطية'),
            subtitle: const Text('ملف يحوي كل بياناتك لنقلها لهاتف آخر'),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('استعادة نسخة احتياطية'),
            subtitle: const Text('يستبدل البيانات الحالية بمحتوى الملف'),
            onTap: _restoreBackup,
          ),
          const Divider(height: 32),
          const Text('البيانات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: const Text(
              'حذف كل البيانات',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () => _confirmDeleteAll(context),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool number = false, bool phone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onTap: () => Fmt.selectAll(c),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : (phone ? TextInputType.phone : null),
        onChanged: phone ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  static const _palette = [
    Color(0xFF2563EB), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFFEC4899), Color(0xFF0D9488), Color(0xFF475569),
  ];

  Widget _headerPreview() {
    final rep = _rep.text.trim(), dist = _dist.text.trim();
    if (rep.isEmpty && dist.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('معاينة ترويسة الفاتورة', style: TextStyle(fontSize: 11, color: AppColors.grey)),
          Text(_name.text, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (rep.isNotEmpty)
            Row(children: [
              const Icon(Icons.phone, size: 13),
              const SizedBox(width: 4),
              Text('المندوب: $rep', style: const TextStyle(fontSize: 12)),
            ]),
          if (dist.isNotEmpty)
            Row(children: [
              const Icon(Icons.phone, size: 13),
              const SizedBox(width: 4),
              Text('الموزع: $dist', style: const TextStyle(fontSize: 12)),
            ]),
        ],
      ),
    );
  }

  Future<void> _pinCapital() async {
    final s = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (s.dollarBuyRate <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('حدّد سعر شراء الدولار أولاً واحفظ')));
      return;
    }
    final cap = CapitalSummary.compute(
      products: context.read<ProductProvider>().products,
      invoices: context.read<InvoiceProvider>().invoices,
      parties: context.read<PartyProvider>(),
      cash: context.read<CashProvider>().balance,
    );
    final usd = cap.capital / s.dollarBuyRate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تثبيت رأس المال'),
        content: Text(
          'رأس المال الحالي: ${Fmt.money(cap.capital, s.currency)}\n'
          'بسعر شراء الدولار ${Fmt.num2(s.dollarBuyRate)} = \$${Fmt.num2(usd)}\n\n'
          'سيُحفظ كرأس مال مرجعي بالدولار.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تثبيت')),
        ],
      ),
    );
    if (ok != true) return;
    await s.setReferenceCapital(usd, s.dollarBuyRate);
    await CapitalSnapshots.save(capitalSyp: cap.capital, buyRate: s.dollarBuyRate);
    messenger.showSnackBar(const SnackBar(content: Text('تم تثبيت رأس المال المرجعي')));
  }

  Future<void> _reloadAll() async {
    await context.read<SettingsProvider>().load();
    await context.read<ProductProvider>().loadProducts();
    await context.read<InvoiceProvider>().loadInvoices();
    await context.read<PartyProvider>().loadAll();
    await context.read<ExpenseProvider>().load();
    if (mounted) await context.read<CashProvider>().refresh();
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await BackupService.export();
      await Share.shareXFiles([XFile(file.path)], subject: 'نسخة احتياطية - مخزني');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّر التصدير: $e')));
    }
  }

  Future<void> _restoreBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.single.bytes;
    if (bytes == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة نسخة'),
        content: const Text('ستُستبدل كل البيانات الحالية بمحتوى هذه النسخة. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BackupService.restore(utf8.decode(bytes));
      await _reloadAll();
      messenger.showSnackBar(const SnackBar(content: Text('تمت الاستعادة بنجاح')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذّرت الاستعادة: $e')));
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تحذير'),
        content: const Text(
            'سيتم حذف كل الأصناف والفواتير نهائياً. هل أنت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAll();
              if (context.mounted) {
                await context.read<ProductProvider>().loadProducts();
                await context.read<InvoiceProvider>().loadInvoices();
                if (context.mounted) await context.read<PartyProvider>().loadAll();
              }
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف كل البيانات')),
                );
              }
            },
            child: const Text(
              'حذف الكل',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}