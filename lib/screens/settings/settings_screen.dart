import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/database/database_helper.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _name = TextEditingController(text: s.storeName);
    _phone = TextEditingController(text: s.phone);
    _address = TextEditingController(text: s.address);
    _currency = TextEditingController(text: s.currency);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
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
          _field(_phone, 'رقم الهاتف', Icons.phone),
          _field(_address, 'العنوان', Icons.location_on),
          _field(_currency, 'العملة', Icons.monetization_on),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await s.update(
                  storeName: _name.text,
                  phone: _phone.text,
                  address: _address.text,
                  currency: _currency.text,
                );
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

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
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