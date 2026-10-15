import 'package:flutter_test/flutter_test.dart';
import 'package:repository/core/utils/arabic_words.dart';
import 'package:repository/core/utils/cash_service.dart';
import 'package:repository/data/models/party.dart';
import 'package:repository/data/models/purchase.dart';
import 'package:repository/providers/party_provider.dart';
import 'package:repository/core/utils/period.dart';
import 'package:repository/core/utils/pricing.dart';
import 'package:repository/core/utils/report_data.dart';
import 'package:repository/data/models/expense.dart';
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

  test('تقرير: ربح إجمالي ومصاريف وصافي ضمن فترة', () {
    final it = InvoiceItem(
        productName: 'A', productId: 1, quantity: 10, buyPrice: 60, sellPrice: 100);
    final inside = Invoice(number: '1', customerName: 'x', date: DateTime(2026, 5, 10), items: [it]);
    final outside = Invoice(
        number: '2',
        customerName: 'y',
        date: DateTime(2026, 6, 10),
        items: [InvoiceItem(productName: 'A', productId: 1, quantity: 1, buyPrice: 60, sellPrice: 100)]);
    final r = ReportData(
      range: PeriodRange.of(PeriodKind.month, DateTime(2026, 5, 20)),
      allInvoices: [inside, outside],
      allExpenses: [
        Expense(category: 'إيجار', amount: 100, date: DateTime(2026, 5, 2)),
        Expense(category: 'العروض', amount: 60, date: DateTime(2026, 5, 10), invoiceId: 1),
        Expense(category: 'إيجار', amount: 999, date: DateTime(2026, 7, 1)),
      ],
    );
    expect(r.sales, 1000);
    expect(r.grossProfit, 400);
    expect(r.expensesTotal, 160);
    expect(r.netProfit, 240);
    expect(r.expensesByCategory.first.key, 'إيجار');
    expect(r.percentOfExpenses(100), 62.5);
  });

  test('الأسبوع يبدأ يوم السبت', () {
    final r = PeriodRange.of(PeriodKind.week, DateTime(2026, 10, 14)); // أربعاء
    expect(r.start, DateTime(2026, 10, 10)); // السبت
    expect(r.end, DateTime(2026, 10, 17));
  });

  test('هدايا الشركة مجانية وهداياي تكلفتها مصروف + حركة الأصناف', () {
    final paid = InvoiceItem(
        id: 1, productName: 'A', productId: 1, quantity: 10, buyPrice: 60, sellPrice: 100);
    final mine = InvoiceItem(
        productName: 'A', productId: 1, quantity: 2, buyPrice: 60, sellPrice: 0,
        isGift: true, giftType: 'mine');
    final co = InvoiceItem(
        productName: 'A', productId: 1, quantity: 3, buyPrice: 60, sellPrice: 0,
        isGift: true, giftType: 'company');
    final inv = Invoice(
        id: 7, number: '1', customerName: 'x', date: DateTime(2026, 5, 10),
        items: [paid, mine, co]);
    expect(inv.giftCost, 120); // هداياي فقط: 2 × 60
    expect(inv.totalCost, 600); // المباع فقط
    final rows = Movement.compute([inv], DateTime(2026, 5, 1), DateTime(2026, 5, 31));
    expect(rows.single.qty, 10);
    expect(rows.single.giftsMine, 2);
    expect(rows.single.giftsCompany, 3);
    expect(rows.single.invoiceIds.length, 1);
    expect(rows.single.revenue, 1000);
    expect(rows.single.profit, 280); // 400 - 120
  });

  test('تفقيط المبالغ بالعربية', () {
    expect(ArabicWords.convert(0), 'صفر');
    expect(ArabicWords.convert(1500), 'ألف و خمسمئة'.replaceAll('و ', 'و'));
    expect(ArabicWords.convert(2000), 'ألفان');
    expect(ArabicWords.convert(25000), 'خمسة وعشرون ألف');
    expect(ArabicWords.convert(3000), 'ثلاثة آلاف');
    expect(ArabicWords.convert(2350000), 'مليونان وثلاثمئة وخمسون ألف');
    expect(ArabicWords.money(1500), 'ألف وخمسمئة ليرة سورية فقط لا غير');
  });

  test('تكلفة القطعة الفعلية مع الشحن لا تزيد دين المورّد', () {
    final it = PurchaseItem(
        productId: 1, productName: 'A', quantity: 10, buyPrice: 100, extraCost: 100);
    final inv = PurchaseInvoice(
        supplierId: 1, date: DateTime(2026), items: [it], shippingCost: 60, otherCost: 40);
    expect(inv.total, 1000); // دين المورّد بلا الشحن
    expect(it.landedUnit, 110); // التكلفة الفعلية للقطعة
    expect(inv.extraTotal, 100);
  });

  test('رصيد المورّد مع المرتجعات وإمكانية الرصيد الدائن', () {
    final p = PartyProvider();
    p.suppliers = [Party(id: 1, name: 'م')];
    p.purchases = [
      PurchaseInvoice(
        supplierId: 1,
        date: DateTime(2026),
        paidAmount: 1000,
        items: [PurchaseItem(productId: 1, productName: 'A', quantity: 10, buyPrice: 100)],
      ),
    ];
    expect(p.supplierBalance(1), 0);
    p.supplierReturns = [
      SupplierReturn(
        supplierId: 1,
        date: DateTime(2026),
        items: [SupplierReturnItem(productId: 1, productName: 'A', quantity: 2, unitPrice: 100)],
      ),
    ];
    expect(p.supplierBalance(1), -200); // مدفوع مسبقاً → رصيد لصالحي
  });

  test('الرصيد النظري للدرج', () {
    final b = CashBreakdown(
      hasBaseline: true,
      baseline: 1000,
      cashSales: 500,
      collections: 200,
      manualIn: 100,
      supplierPayments: 300,
      expenses: 50,
      shipping: 20,
      refunds: 30,
      manualOut: 10,
    );
    expect(b.theoretical, 1390);
  });
}
