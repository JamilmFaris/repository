import 'package:flutter/material.dart';
import '../screens/coupons/coupons_screen.dart';
import '../screens/purchases/purchases_screen.dart';
import '../screens/reservations/reservations_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';

/// القائمة الجانبية: الأقسام غير الموجودة في التبويبات السفلية.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              title: Text('مخزني', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text('إدارة المخزون والمبيعات'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('الموردون'),
              onTap: () => _go(context, const SuppliersScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('فواتير الشراء'),
              onTap: () => _go(context, const PurchasesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_added),
              title: const Text('الحجوزات'),
              onTap: () => _go(context, const ReservationsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.local_offer),
              title: const Text('الكوبونات'),
              onTap: () => _go(context, const CouponsScreen()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('الإعدادات والنسخ الاحتياطي'),
              onTap: () => _go(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
