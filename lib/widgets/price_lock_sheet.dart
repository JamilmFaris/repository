import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models/product.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';

/// 🔒 تثبيت السعر: تبديل + اختيار (شراء فقط / بيع فقط / الاثنان).
Future<void> showPriceLockSheet(BuildContext context, Product p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LockSheet(product: p),
  );
}

class _LockSheet extends StatefulWidget {
  final Product product;
  const _LockSheet({required this.product});
  @override
  State<_LockSheet> createState() => _LockSheetState();
}

class _LockSheetState extends State<_LockSheet> {
  late bool _on = widget.product.isLocked;
  late String _mode = widget.product.isLocked ? widget.product.lockMode : 'both';

  @override
  Widget build(BuildContext context) {
    final s = context.read<SettingsProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔒 تثبيت السعر — ${widget.product.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('السعر المثبّت لا يتغيّر عند تغيّر سعر الدولار.',
              style: TextStyle(fontSize: 12)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تفعيل تثبيت السعر'),
            value: _on,
            onChanged: (v) => setState(() => _on = v),
          ),
          if (_on)
            RadioGroup<String>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              child: const Column(
                children: [
                  RadioListTile<String>(value: 'buy', title: Text('تثبيت سعر الشراء فقط')),
                  RadioListTile<String>(value: 'sell', title: Text('تثبيت سعر البيع فقط')),
                  RadioListTile<String>(value: 'both', title: Text('تثبيت السعرين معاً')),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final prods = context.read<ProductProvider>();
                final nav = Navigator.of(context);
                if (_on) {
                  await prods.setLock(widget.product, _mode, s.dollarBuyRate, s.dollarRate);
                } else if (widget.product.isLocked) {
                  await prods.unlock(widget.product, s.dollarBuyRate, s.dollarRate);
                }
                nav.pop();
              },
              child: const Text('حفظ'),
            ),
          ),
        ],
      ),
    );
  }
}
