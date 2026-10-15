/// تفقيط الأرقام بالعربية (للوصولات): 1500 ← «ألف وخمسمئة».
class ArabicWords {
  static const _ones = [
    '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة',
    'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر',
    'ثمانية عشر', 'تسعة عشر',
  ];
  static const _tens = [
    '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون',
  ];
  static const _hundreds = [
    '', 'مئة', 'مئتان', 'ثلاثمئة', 'أربعمئة', 'خمسمئة', 'ستمئة', 'سبعمئة', 'ثمانمئة', 'تسعمئة',
  ];

  // [مفرد، مثنى، جمع (3-10)]
  static const _scales = [
    ['', '', ''],
    ['ألف', 'ألفان', 'آلاف'],
    ['مليون', 'مليونان', 'ملايين'],
    ['مليار', 'ملياران', 'مليارات'],
    ['تريليون', 'تريليونان', 'تريليونات'],
  ];

  static String _below1000(int n) {
    final parts = <String>[];
    final h = n ~/ 100, r = n % 100;
    if (h > 0) parts.add(_hundreds[h]);
    if (r > 0) {
      if (r < 20) {
        parts.add(_ones[r]);
      } else {
        final u = r % 10, t = r ~/ 10;
        parts.add(u > 0 ? '${_ones[u]} و${_tens[t]}' : _tens[t]);
      }
    }
    return parts.join(' و');
  }

  /// يحوّل عدداً صحيحاً غير سالب إلى كلمات.
  static String convert(int n) {
    if (n == 0) return 'صفر';
    if (n < 0) return 'سالب ${convert(-n)}';
    final groups = <int>[];
    var x = n;
    while (x > 0) {
      groups.add(x % 1000);
      x ~/= 1000;
    }
    final out = <String>[];
    for (var i = groups.length - 1; i >= 0; i--) {
      final v = groups[i];
      if (v == 0) continue;
      if (i == 0) {
        out.add(_below1000(v));
      } else if (i >= _scales.length) {
        out.add('${_below1000(v)} × 10^${i * 3}');
      } else if (v == 1) {
        out.add(_scales[i][0]);
      } else if (v == 2) {
        out.add(_scales[i][1]);
      } else if (v <= 10) {
        out.add('${_below1000(v)} ${_scales[i][2]}');
      } else {
        out.add('${_below1000(v)} ${_scales[i][0]}');
      }
    }
    return out.join(' و');
  }

  /// «ألف وخمسمئة ليرة سورية فقط لا غير».
  static String money(double amount, {String currencyName = 'ليرة سورية'}) {
    return '${convert(amount.round())} $currencyName فقط لا غير';
  }
}
