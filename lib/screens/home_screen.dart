import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/capital.dart';
import '../providers/cash_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/party_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/dashboard_strip.dart';
import 'customers/customers_screen.dart';
import 'expenses/expenses_screen.dart';
import 'invoices/invoices_screen.dart';
import 'products/products_screen.dart';
import 'reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _snapScheduled = false;

  static const _screens = [
    ProductsScreen(),
    InvoicesScreen(),
    CustomersScreen(),
    ExpensesScreen(),
    ReportsScreen(),
  ];

  /// لقطة شهرية لرأس المال بالدولار (مرة واحدة لكل شهر عند فتح التطبيق).
  void _scheduleSnapshot() {
    if (_snapScheduled) return;
    final settings = context.read<SettingsProvider>();
    final prods = context.read<ProductProvider>().products;
    if (settings.dollarBuyRate <= 0 || prods.isEmpty) return;
    _snapScheduled = true;
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final cap = CapitalSummary.compute(
        products: context.read<ProductProvider>().products,
        invoices: context.read<InvoiceProvider>().invoices,
        parties: context.read<PartyProvider>(),
        cash: context.read<CashProvider>().balance,
      );
      await CapitalSnapshots.save(
        capitalSyp: cap.capital,
        buyRate: context.read<SettingsProvider>().dollarBuyRate,
        overwrite: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProductProvider>();
    context.watch<SettingsProvider>();
    _scheduleSnapshot();

    return Scaffold(
      body: Column(
        children: [
          // لوحة التحكم الذكية أعلى التطبيق (تحت شريط الحالة)
          const SafeArea(bottom: false, child: DashboardStrip()),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              // تبديل ناعم بين التبويبات مع الاحتفاظ بحالة كل شاشة
              child: Stack(
                children: [
                  for (var i = 0; i < _screens.length; i++)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: i != _index,
                        child: TickerMode(
                          enabled: i == _index,
                          child: AnimatedOpacity(
                            opacity: i == _index ? 1 : 0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            child: _screens[i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'الأصناف'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الفواتير'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الزبائن'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'المصاريف'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
        ],
      ),
    );
  }
}
