import 'package:intl/intl.dart';

class Fmt {
  static final _num = NumberFormat('#,##0.##', 'en');
  static final _date = DateFormat('yyyy/MM/dd', 'en');
  static final _dateTime = DateFormat('yyyy/MM/dd HH:mm', 'en');

  static String money(double v, String currency) => '${_num.format(v)} $currency';
  static String num2(num v) => _num.format(v);
  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
}