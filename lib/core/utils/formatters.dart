import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class Fmt {
  static final _num = NumberFormat('#,##0.##', 'en');
  static final _date = DateFormat('yyyy/MM/dd', 'en');
  static final _time = DateFormat('hh:mm a', 'en');
  static final _dateTime = DateFormat('yyyy/MM/dd HH:mm', 'en');

  /// يحوّل الأرقام العربية (٠-٩) والفاصلة العربية إلى لاتينية ثم يقرأ الرقم.
  static double? parseNum(String v) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in v.trim().split('')) {
      final i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : (ch == '٫' || ch == ',' ? '.' : ch));
    }
    return double.tryParse(b.toString());
  }

  /// يحدّد كامل النص في الحقل ليُستبدَل الرقم القديم بمجرد الكتابة.
  static void selectAll(TextEditingController c) {
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  static String money(double v, String currency) => '${_num.format(v)} $currency';
  static String num2(num v) => _num.format(v);
  static String date(DateTime d) => _date.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
}
