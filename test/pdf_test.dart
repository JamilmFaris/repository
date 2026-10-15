import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:repository/core/utils/capital.dart';
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
}
