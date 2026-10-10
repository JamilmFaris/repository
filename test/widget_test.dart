import 'package:flutter_test/flutter_test.dart';
import 'package:repository/core/utils/pricing.dart';
import 'package:repository/data/models/invoice.dart';
import 'package:repository/data/models/invoice_item.dart';

void main() {
  test('تقريب الدولار للسوري لأقرب 50 للأعلى', () {
    expect(Pricing.usdToSyp(1, 2410), 2450);
    expect(Pricing.usdToSyp(1, 2435), 2450);
    expect(Pricing.usdToSyp(1, 2488), 2500);
    expect(Pricing.usdToSyp(1, 2450), 2450);
    expect(Pricing.usdToSyp(0.125, 15000), 1900); // 1875 -> 1900
  });

  test('خصم صنف ونسبة فاتورة وهدية ومرتجع', () {
    final paid = InvoiceItem(
      productName: 'A', productId: 1, quantity: 5,
      buyPrice: 60, sellPrice: 100,
      discountType: 'percent', discountValue: 10, // 500 -> 450
    );
    final gift = InvoiceItem(
      productName: 'A', productId: 1, quantity: 1,
      buyPrice: 60, sellPrice: 0, isGift: true,
    );
    final inv = Invoice(
      number: '1', customerName: 'x', date: DateTime(2026),
      items: [paid, gift], discountType: 'amount', discountValue: 50,
    );
    expect(paid.totalSell, 450);
    expect(inv.subtotal, 450);
    expect(inv.invoiceDiscount, 50);
    expect(inv.total, 400);
    expect(inv.totalCost, 300); // الهدية خارج التكلفة
    expect(inv.giftCost, 60); // تذهب لمصاريف العروض
    expect(inv.totalProfit, 100);

    paid.returnedQty = 1; // مرتجع قطعة
    expect(paid.totalSell, 360); // 450 * 4/5
    expect(paid.soldQty, 4);
    expect(inv.total, 310);
  });
}
