import '../../data/models/invoice_item.dart';
import 'formatters.dart';

/// نصوص مشتركة بين شاشة الفاتورة والـPDF.
String invoiceItemName(InvoiceItem it) =>
    it.isGift ? '${it.productName} (هدية)' : it.productName;

/// سطر ملاحظة تحت اسم الصنف: الخصم (نسبة/مبلغ) والمرتجع. null إن لم يوجد.
String? invoiceItemNote(InvoiceItem it, String currency) {
  final parts = <String>[];
  if (it.discountAmount > 0) {
    final amt = Fmt.num2(it.discountAmount);
    parts.add(it.discountType == 'percent'
        ? 'خصم ${Fmt.num2(it.discountValue)}% = $amt $currency'
        : 'خصم $amt $currency');
  }
  if (it.returnedQty > 0) parts.add('مرتجع ${it.returnedQty}');
  return parts.isEmpty ? null : parts.join(' • ');
}
