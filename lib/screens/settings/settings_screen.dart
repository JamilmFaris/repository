import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/backup_service.dart';
import '../../providers/expense_provider.dart';
import '../../data/database/database_helper.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/party_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../coupons/coupons_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _name = TextEditingController(text: s.storeName);
    _phone = TextEditingController(text: s.phone);
    _address = TextEditingController(text: s.address);
    _currency = TextEditingController(text: s.currency);
    _rate = TextEditingController(
        text: s.dollarRate > 0 ? (s.dollarRate == s.dollarRate.roundToDouble() ? s.dollarRate.toInt().toString() : s.dollarRate.toString()) : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();

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
          _field(_rate, 'سعر الدولار', Icons.attach_money, number: true),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final rate = double.tryParse(_rate.text.trim()) ?? 0;
                final changed = rate != s.dollarRate;
                final products = context.read<ProductProvider>();
                await s.update(
                  storeName: _name.text,
                  phone: _phone.text,
                  address: _address.text,
                  currency: _currency.text,
                  dollarRate: rate,
                );
                if (changed && rate > 0) await products.repriceAll(rate);
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
          const Text('لون التطبيق'),
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

  Widget _field(TextEditingController c, String label, IconData icon, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onTap: () => Fmt.selectAll(c),
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
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

  Future<void> _reloadAll() async {
    await context.read<SettingsProvider>().load();
    await context.read<ProductProvider>().loadProducts();
    await context.read<InvoiceProvider>().loadInvoices();
    await context.read<PartyProvider>().loadAll();
    await context.read<ExpenseProvider>().load();
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