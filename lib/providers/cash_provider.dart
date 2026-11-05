import 'package:flutter/foundation.dart';
import '../core/utils/cash_service.dart';

/// رصيد الصندوق (الدرج): يُعاد حسابه عند تغيّر الفواتير أو الدفعات أو المصاريف.
class CashProvider extends ChangeNotifier {
  CashBreakdown breakdown = CashBreakdown(hasBaseline: false);
  List<CashMovement> movements = [];
  List<CashCount> counts = [];
  List<CashEntry> autoEntries = [];
  CashCount? opening;

  double get balance => breakdown.theoretical;
  bool get hasBaseline => breakdown.hasBaseline;

  Future<void> refresh() async {
    breakdown = await CashService.compute();
    movements = await CashService.movements();
    counts = await CashService.counts();
    autoEntries = await CashService.autoEntries();
    opening = await CashService.openingCount();
    notifyListeners();
  }

  Future<void> addMovement(String type, double amount, String reason) async {
    await CashService.addMovement(type, amount, reason);
    await refresh();
  }

  Future<void> deleteMovement(int id) async {
    await CashService.deleteMovement(id);
    await refresh();
  }

  /// الرصيد الافتتاحي للمرة الأولى: يُسجَّل كجرد نظري = فعلي.
  Future<void> saveOpening(double amount, {double usd = 0, double rate = 0}) async {
    await CashService.saveOpening(amount, usd: usd, rate: rate);
    await refresh();
  }

  /// تصحيح الرصيد الافتتاحي المُدخل بالخطأ.
  Future<void> updateOpening(int id, double amount, {double usd = 0, double rate = 0}) async {
    await CashService.updateOpening(id, amount, usd: usd, rate: rate);
    await refresh();
  }

  Future<void> saveCount(double actual, String note) async {
    final fresh = await CashService.compute();
    await CashService.saveCount(theoretical: fresh.theoretical, actual: actual, note: note);
    await refresh();
  }
}
