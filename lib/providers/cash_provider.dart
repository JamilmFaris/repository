import 'package:flutter/foundation.dart';
import '../core/utils/cash_service.dart';

/// رصيد الصندوق (الدرج): يُعاد حسابه عند تغيّر الفواتير أو الدفعات أو المصاريف.
class CashProvider extends ChangeNotifier {
  CashBreakdown breakdown = CashBreakdown(hasBaseline: false);
  List<CashMovement> movements = [];
  List<CashCount> counts = [];

  double get balance => breakdown.theoretical;
  bool get hasBaseline => breakdown.hasBaseline;

  Future<void> refresh() async {
    breakdown = await CashService.compute();
    movements = await CashService.movements();
    counts = await CashService.counts();
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
  Future<void> saveOpening(double amount) async {
    await CashService.saveCount(theoretical: amount, actual: amount, note: 'رصيد افتتاحي');
    await refresh();
  }

  Future<void> saveCount(double actual, String note) async {
    final fresh = await CashService.compute();
    await CashService.saveCount(theoretical: fresh.theoretical, actual: actual, note: note);
    await refresh();
  }
}
