class Pricing {
  /// تحويل الدولار إلى سوري: الناتج يُقرَّب دائماً للأعلى لأقرب 50.
  static double usdToSyp(double usd, double rate) {
    final v = usd * rate;
    final clean = (v * 1e6).round() / 1e6; // تفادي أخطاء الفاصلة العائمة
    return (clean / 50).ceil() * 50.0;
  }
}
