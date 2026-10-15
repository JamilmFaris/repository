import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'providers/cash_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/product_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/party_provider.dart';
import 'providers/report_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MakhzaniApp());
}

class MakhzaniApp extends StatelessWidget {
  const MakhzaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()..loadInvoices()),
        ChangeNotifierProvider(create: (_) => PartyProvider()..loadAll()),
        ChangeNotifierProxyProvider<InvoiceProvider, ExpenseProvider>(
          create: (_) => ExpenseProvider()..load(),
          update: (_, inv, exp) => exp!..load(),
        ),
        // رصيد الصندوق يُعاد حسابه عند تغيّر الفواتير أو الدفعات أو المصاريف
        ChangeNotifierProxyProvider3<InvoiceProvider, PartyProvider, ExpenseProvider, CashProvider>(
          create: (_) => CashProvider()..refresh(),
          update: (_, inv, parties, exp, cash) => cash!..refresh(),
        ),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'مخزني',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
                style: settings.appStyle, seed: Color(settings.themeColor), dark: false),
            darkTheme: AppTheme.build(
                style: settings.appStyle, seed: Color(settings.themeColor), dark: true),
            themeMode: settings.appStyle == 'luxury'
                ? ThemeMode.dark
                : settings.appStyle == 'calm'
                    ? ThemeMode.light
                    : (settings.isDarkMode ? ThemeMode.dark : ThemeMode.light),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              // منع تكبير الخط المفرط من إعدادات الهاتف حتى لا تتشوّه الشاشات الصغيرة
              child: MediaQuery.withClampedTextScaling(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.15,
                child: child!,
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}