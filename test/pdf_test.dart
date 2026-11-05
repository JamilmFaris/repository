import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repository/screens/receipts/receipt_view_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repository/core/utils/analytics.dart';
import 'package:repository/core/utils/capital.dart';
import 'package:repository/core/utils/statement_pdf.dart';
import 'package:repository/core/utils/stock_pdf.dart';
import 'package:repository/data/models/party.dart';
import 'package:repository/data/models/product.dart';
import 'package:repository/core/utils/invoice_pdf.dart';
import 'package:repository/core/utils/movement_pdf.dart';
import 'package:repository/core/utils/period.dart';
import 'package:repository/core/utils/receipt_pdf.dart';
import 'package:repository/core/utils/report_pdf.dart';
import 'package:repository/data/models/receipt.dart';
import 'package:repository/data/models/expense.dart';
import 'package:repository/data/models/invoice.dart';
import 'package:repository/data/models/invoice_item.dart';
import 'package:repository/providers/settings_provider.dart';
import 'package:repository/core/utils/report_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en'));

  test('بناء PDF حركة الأصناف', () async {
    final r = MovementRow(1, 'باراسيتامول 500')
      ..qty = 10
      ..giftsMine = 1
      ..giftsCompany = 2
      ..revenue = 12345.5
      ..profit = 2000
      ..invoiceIds.addAll([1, 2]);
    final bytes = await MovementPdf.build(
      rows: [r],
      from: DateTime(2026, 5, 1),
      to: DateTime(2026, 5, 31),
      storeName: 'مستودع',
      currency: 'ل.س',
    );
    expect(bytes.length, greaterThan(1000));
  });

  final inv = Invoice(
    id: 1,
    number: '5',
    customerName: 'صيدلية النور',
    date: DateTime(2026, 5, 10, 14, 30),
    notes: 'ملاحظة',
    items: [
      InvoiceItem(
          productName: 'باراسيتامول', productId: 1, quantity: 5, buyPrice: 60, sellPrice: 100,
          discountType: 'percent', discountValue: 10),
      InvoiceItem(
          productName: 'باراسيتامول', productId: 1, quantity: 1, buyPrice: 60, sellPrice: 0,
          isGift: true),
    ],
    discountType: 'amount',
    discountValue: 20,
  );

  test('بناء PDF الفاتورة', () async {
    final s = SettingsProvider()
      ..storeName = 'مستودع'
      ..phone = '0999'
      ..repPhone = '0911'
      ..distPhone = '0922';
    final bytes = await InvoicePdf.build(inv, s);
    expect(bytes.length, greaterThan(1000));
  });

  test('بناء PDF التقرير', () async {
    final data = ReportData(
      range: PeriodRange.of(PeriodKind.month, DateTime(2026, 5, 20)),
      allInvoices: [inv],
      allExpenses: [Expense(category: 'إيجار', amount: 50, date: DateTime(2026, 5, 2))],
    );
    final bytes = await ReportPdf.build(
      data: data,
      capital: CapitalSummary(stockBuy: 1, stockSell: 2, customersOwed: 0, suppliersOwed: 0),
      storeName: 'مستودع',
      currency: 'ل.س',
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('بناء PDF وصل الدفع', () async {
    final bytes = await ReceiptPdf.build(
      receipt: Receipt(
        number: 3,
        customerName: 'صيدلية النور',
        amount: 150000,
        purpose: 'سداد دَين',
        note: 'دفعة أولى',
        date: DateTime(2026, 10, 15, 11, 5),
      ),
      storeName: 'مستودع',
      phone: '0999',
      currency: 'ل.س',
    );
    expect(bytes.length, greaterThan(1000));
  });

  final products = [
    Product(id: 1, name: 'كريم مرطّب', quantity: 48, buyPrice: 100, sellPrice: 150,
        companyBuyQty: 1, companyFreeQty: 1),
    Product(id: 2, name: 'شامبو', quantity: 0, buyPrice: 50, sellPrice: 80),
    Product(id: 3, name: 'صابون', quantity: 3, buyPrice: 10, sellPrice: 20),
    Product(id: 4, name: 'عطر', quantity: 40, buyPrice: 500, sellPrice: 700),
  ];

  test('رأس المال: عرض الشركة يخصم قطع الهدايا (48 قطعة 1+1 = 24 مدفوعة)', () {
    expect(products[0].paidQuantity, 24);
    expect(products[1].paidQuantity, 0);
    expect(products[2].paidQuantity, 3);
    // مجموعة ناقصة: 5 قطع بعرض 1+1 → 3 مدفوعة
    expect(Product(name: 'x', quantity: 5, buyPrice: 1, sellPrice: 1, companyBuyQty: 1, companyFreeQty: 1)
        .paidQuantity, 3);
    // عرض 2+1: 10 قطع = 3 مجموعات (6 مدفوعة) + قطعة مدفوعة
    expect(Product(name: 'x', quantity: 10, buyPrice: 1, sellPrice: 1, companyBuyQty: 2, companyFreeQty: 1)
        .paidQuantity, 7);
  });

  test('بناء PDF جرد الأصناف والنواقص', () async {
    final inv = await StockPdf.buildInventory(products: products, storeName: 'مستودع', lowThreshold: 5);
    expect(inv.length, greaterThan(1000));
    final alerts = await StockPdf.buildAlerts(products: products, storeName: 'مستودع', lowThreshold: 5);
    expect(alerts.length, greaterThan(1000));
  });

  test('بناء PDF كشف حساب الزبون', () async {
    final bytes = await StatementPdf.build(
      customer: Party(id: 1, name: 'صيدلية النور', phone: '0999'),
      invoices: [inv..customerId = 1..paidAmount = 100],
      payments: [PartyPayment(id: 1, partyId: 1, amount: 50, date: DateTime(2026, 5, 20), note: 'دفعة')],
      storeName: 'مستودع',
      phone: '0999',
      address: 'دمشق',
      currency: 'ل.س',
    );
    expect(bytes.length, greaterThan(1000));
  });

  test('تحليلات: الأكثر طلباً والراكد واقتراح الطلب', () {
    final now = DateTime(2026, 6, 1);
    final sales = Invoice(
      id: 9,
      number: '9',
      customerName: 'ز',
      date: DateTime(2026, 5, 25),
      items: [InvoiceItem(productId: 3, productName: 'صابون', quantity: 30, buyPrice: 10, sellPrice: 20)],
    );
    final f = Analytics.flows(products, [sales], 30, now: now);
    expect(Analytics.fast(f).first.product.id, 3);
    expect(Analytics.stagnant(f).map((x) => x.product.id), containsAll([1, 4]));
    final r = Analytics.reorder(f, 30);
    expect(r.single.flow.product.id, 3);
    expect(r.single.qty, greaterThan(0));
    expect(Analytics.shiftMonths(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
  });

  testWidgets('ورقة الوصل تُعرض مع الختم والتوقيع بدون أخطاء', (tester) async {
    final s = SettingsProvider()..storeName = 'مستودع';
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptPaper(
              receipt: Receipt(
                  number: 1, customerName: 'صيدلية', amount: 1000, date: DateTime(2026, 1, 1)),
              settings: s,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('التوقيع'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
