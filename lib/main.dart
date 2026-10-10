import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
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
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'مخزني',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(Color(settings.themeColor)),
            darkTheme: AppTheme.dark(Color(settings.themeColor)),
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}