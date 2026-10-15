import 'package:flutter/foundation.dart';
import '../data/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepository();
  String storeName = 'متجري';
  String phone = '';
  String address = '';
  String currency = 'ل.س';
  bool isDarkMode = false;

  /// سعر بيع الدولار (يُستخدم لتسعير المبيع وعرض الربح بالدولار).
  double dollarRate = 0;

  /// سعر شراء الدولار (يُستخدم لتسعير الشراء وتقييم رأس المال).
  double dollarBuyRate = 0;
  int themeColor = 0xFF2563EB;
  String repPhone = '';
  String distPhone = '';

  /// الحد الأدنى للمخزون: عند هذه الكمية أو أقل يُعتبر الصنف «وصل للحد الأدنى».
  int lowStock = 5;

  /// نمط التطبيق: normal | luxury (فاخر) | calm (هادئ).
  String appStyle = 'normal';

  /// رأس المال المرجعي المثبَّت بالدولار، مع سعر الصرف وتاريخ التثبيت.
  double refCapitalUsd = 0;
  double refCapitalRate = 0;
  DateTime? refCapitalDate;

  Future<void> load() async {
    final m = await _repo.load();
    storeName = m['storeName'];
    phone = m['phone'];
    address = m['address'];
    currency = m['currency'];
    isDarkMode = m['dark'];
    dollarRate = m['dollarRate'];
    dollarBuyRate = m['dollarBuyRate'];
    themeColor = m['themeColor'];
    repPhone = m['repPhone'];
    distPhone = m['distPhone'];
    lowStock = m['lowStock'];
    appStyle = m['appStyle'];
    refCapitalUsd = m['refCapitalUsd'];
    refCapitalRate = m['refCapitalRate'];
    final d = m['refCapitalDate'] as String?;
    refCapitalDate = d == null ? null : DateTime.tryParse(d);
    notifyListeners();
  }

  Future<void> update({
    String? storeName,
    String? phone,
    String? address,
    String? currency,
    bool? dark,
    double? dollarRate,
    double? dollarBuyRate,
    String? repPhone,
    String? distPhone,
    int? lowStock,
  }) async {
    await _repo.save(
      storeName: storeName,
      phone: phone,
      address: address,
      currency: currency,
      dark: dark,
      dollarRate: dollarRate,
      dollarBuyRate: dollarBuyRate,
      repPhone: repPhone,
      distPhone: distPhone,
      lowStock: lowStock,
    );
    await load();
  }

  /// تثبيت رأس المال المرجعي (بالدولار) بسعر الصرف الحالي.
  Future<void> setReferenceCapital(double usd, double rate) async {
    await _repo.save(
      refCapitalUsd: usd,
      refCapitalRate: rate,
      refCapitalDate: DateTime.now().toIso8601String(),
    );
    await load();
  }

  Future<void> setAppStyle(String v) async {
    appStyle = v;
    await _repo.save(appStyle: v);
    notifyListeners();
  }

  Future<void> setThemeColor(int v) async {
    themeColor = v;
    await _repo.save(themeColor: v);
    notifyListeners();
  }

  Future<void> toggleDark(bool v) async {
    isDarkMode = v;
    await _repo.save(dark: v);
    notifyListeners();
  }
}
