import 'package:flutter/material.dart';
import '../core/utils/formatters.dart';
import '../data/models/party.dart';

/// نافذة إضافة/تعديل زبون أو مورّد. تعيد null عند الإلغاء.
Future<Party?> showPartyDialog(BuildContext context, {Party? initial, required String title}) {
  final name = TextEditingController(text: initial?.name ?? '');
  final phone = TextEditingController(text: initial?.phone ?? '');
  final notes = TextEditingController(text: initial?.notes ?? '');
  return showDialog<Party>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              onTap: () => Fmt.selectAll(phone),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              ctx,
              Party(
                id: initial?.id,
                name: name.text.trim(),
                phone: phone.text.trim(),
                notes: notes.text.trim(),
                createdAt: initial?.createdAt,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class AmountResult {
  final double amount;
  final String note;
  AmountResult(this.amount, this.note);
}

/// نافذة إدخال مبلغ (دفعة) مع ملاحظة.
Future<AmountResult?> showAmountDialog(BuildContext context, {required String title, double? initial}) {
  final amount = TextEditingController(
      text: initial == null || initial <= 0 ? '' : Fmt.num2(initial).replaceAll(',', ''));
    Fmt.selectAll(amount);
  final note = TextEditingController();
  return showDialog<AmountResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            autofocus: true,
            onTap: () => Fmt.selectAll(amount),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        TextButton(
          onPressed: () {
            final v = Fmt.parseNum(amount.text) ?? 0;
            if (v <= 0) return;
            Navigator.pop(ctx, AmountResult(v, note.text.trim()));
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}
