import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _kStoreName = 'store_name';
  static const _kPhone = 'phone';
  static const _kAddress = 'address';
  static const _kCurrency = 'currency';
  static const _kDark = 'dark';
  static const _kRate = 'dollar_rate'; // سعر بيع الدولار (الاسم القديم محفوظ)
  static const _kBuyRate = 'dollar_buy_rate';
  static const _kColor = 'theme_color';
  static const _kRep = 'rep_phone';
  static const _kDist = 'dist_phone';
  static const _kLow = 'low_stock';
  static const _kStyle = 'app_style';
  static const _kRefUsd = 'ref_capital_usd';
  static const _kRefRate = 'ref_capital_rate';
  static const _kRefDate = 'ref_capital_date';

  Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    final sell = p.getDouble(_kRate) ?? 0.0;
    return {
      'storeName': p.getString(_kStoreName) ?? 'متجري',
      'phone': p.getString(_kPhone) ?? '',
      'address': p.getString(_kAddress) ?? '',
      'currency': p.getString(_kCurrency) ?? 'ل.س',
      'dark': p.getBool(_kDark) ?? false,
      'dollarRate': sell,
      // قبل وجود سعر شراء مستقل كان السعر واحداً
      'dollarBuyRate': p.getDouble(_kBuyRate) ?? sell,
      'themeColor': p.getInt(_kColor) ?? 0xFF2563EB,
      'repPhone': p.getString(_kRep) ?? '',
      'distPhone': p.getString(_kDist) ?? '',
      'lowStock': p.getInt(_kLow) ?? 5,
      'appStyle': p.getString(_kStyle) ?? 'normal',
      'refCapitalUsd': p.getDouble(_kRefUsd) ?? 0.0,
      'refCapitalRate': p.getDouble(_kRefRate) ?? 0.0,
      'refCapitalDate': p.getString(_kRefDate),
    };
  }

  Future<void> save({
    String? storeName,
    String? phone,
    String? address,
    String? currency,
    bool? dark,
    double? dollarRate,
    double? dollarBuyRate,
    int? themeColor,
    String? repPhone,
    String? distPhone,
    int? lowStock,
    String? appStyle,
    double? refCapitalUsd,
    double? refCapitalRate,
    String? refCapitalDate,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (storeName != null) await p.setString(_kStoreName, storeName);
    if (phone != null) await p.setString(_kPhone, phone);
    if (address != null) await p.setString(_kAddress, address);
    if (currency != null) await p.setString(_kCurrency, currency);
    if (dark != null) await p.setBool(_kDark, dark);
    if (dollarRate != null) await p.setDouble(_kRate, dollarRate);
    if (dollarBuyRate != null) await p.setDouble(_kBuyRate, dollarBuyRate);
    if (themeColor != null) await p.setInt(_kColor, themeColor);
    if (repPhone != null) await p.setString(_kRep, repPhone);
    if (distPhone != null) await p.setString(_kDist, distPhone);
    if (lowStock != null) await p.setInt(_kLow, lowStock);
    if (appStyle != null) await p.setString(_kStyle, appStyle);
    if (refCapitalUsd != null) await p.setDouble(_kRefUsd, refCapitalUsd);
    if (refCapitalRate != null) await p.setDouble(_kRefRate, refCapitalRate);
    if (refCapitalDate != null) await p.setString(_kRefDate, refCapitalDate);
  }
}
