import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _kStoreName = 'store_name';
  static const _kPhone = 'phone';
  static const _kAddress = 'address';
  static const _kCurrency = 'currency';
  static const _kDark = 'dark';

  Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'storeName': p.getString(_kStoreName) ?? 'متجري',
      'phone': p.getString(_kPhone) ?? '',
      'address': p.getString(_kAddress) ?? '',
      'currency': p.getString(_kCurrency) ?? 'ل.س',
      'dark': p.getBool(_kDark) ?? false,
    };
  }

  Future<void> save({String? storeName, String? phone, String? address, String? currency, bool? dark}) async {
    final p = await SharedPreferences.getInstance();
    if (storeName != null) await p.setString(_kStoreName, storeName);
    if (phone != null) await p.setString(_kPhone, phone);
    if (address != null) await p.setString(_kAddress, address);
    if (currency != null) await p.setString(_kCurrency, currency);
    if (dark != null) await p.setBool(_kDark, dark);
  }
}