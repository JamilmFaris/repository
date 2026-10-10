import 'package:flutter/foundation.dart';
import '../data/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = SettingsRepository();
  String storeName = 'متجري';
  String phone = '';
  String address = '';
  String currency = 'ل.س';
  bool isDarkMode = false;
  double dollarRate = 0;

  Future<void> load() async {
    final m = await _repo.load();
    storeName = m['storeName'];
    phone = m['phone'];
    address = m['address'];
    currency = m['currency'];
    isDarkMode = m['dark'];
    dollarRate = m['dollarRate'];
    notifyListeners();
  }

  Future<void> update({String? storeName, String? phone, String? address, String? currency, bool? dark, double? dollarRate}) async {
    await _repo.save(storeName: storeName, phone: phone, address: address, currency: currency, dark: dark, dollarRate: dollarRate);
    await load();
  }

  Future<void> toggleDark(bool v) async {
    isDarkMode = v;
    await _repo.save(dark: v);
    notifyListeners();
  }
}