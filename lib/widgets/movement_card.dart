import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/movement_pdf.dart';
import '../core/utils/report_data.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';

/// 📊 حركة الأصناف بين تاريخين: المباع والهدايا والإيراد والربح لكل صنف.
class MovementCard extends StatefulWidget {
  const MovementCard({super.key});
  @override
  State<MovementCard> createState() => _MovementCardState();
}

class _MovementCardState extends State<MovementCard> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  int? _productId;
  List<MovementRow>? _rows;

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final settings = context.watch<SettingsProvider>();
    final cur = settings.currency;
    final rows = _rows;

    Widget dateBox(String label, DateTime v, bool from) => Expanded(
          child: InkWell(
            onTap: () => _pick(from),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.event, size: 18),
              ),
              child: Text(Fmt.date(v)),
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.bar_chart, size: 20),
              SizedBox(width: 6),
              Text('حركة الأصناف بين تاريخين',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Row(children: [dateBox('من', _from, true), const SizedBox(width: 8), dateBox('إلى', _to, false)]),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _productId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'الصنف', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('كل الأصناف')),
                for (final p in products) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _productId = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('حساب'),
                    onPressed: () => setState(() {
                      _rows = Movement.compute(
                        context.read<InvoiceProvider>().invoices,
                        _from,
                        _to,
                        productId: _productId,
                      );
                    }),
                  ),
                ),
                if (rows != null && rows.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    onPressed: () => MovementPdf.share(
                      rows: rows,
                      from: _from,
                      to: _to,
                      storeName: settings.storeName,
                      currency: cur,
                    ),
                  ),
                ],
              ],
            ),
            if (rows != null) ...[
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('لا توجد حركة في هذه الفترة', style: TextStyle(color: AppColors.grey))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 14,
                    headingRowHeight: 40,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(label: Text('الصنف')),
                      DataColumn(label: Text('المباع'), numeric: true),
                      DataColumn(label: Text('🎁 حسابي'), numeric: true),
                      DataColumn(label: Text('🎁 الشركة'), numeric: true),
                      DataColumn(label: Text('الفواتير'), numeric: true),
                      DataColumn(label: Text('الإيراد'), numeric: true),
                      DataColumn(label: Text('الربح الصافي'), numeric: true),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(cells: [
                          DataCell(Text(r.name)),
                          DataCell(Text('${r.qty}')),
                          DataCell(Text('${r.giftsMine}')),
                          DataCell(Text('${r.giftsCompany}')),
                          DataCell(Text('${r.invoiceIds.length}')),
                          DataCell(Text(Fmt.num2(r.revenue))),
                          DataCell(Text(Fmt.num2(r.profit))),
                        ]),
                      DataRow(
                        color: WidgetStatePropertyAll(
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)),
                        cells: [
                          const DataCell(Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('${rows.fold<int>(0, (s, r) => s + r.qty)}',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('${rows.fold<int>(0, (s, r) => s + r.giftsMine)}',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('${rows.fold<int>(0, (s, r) => s + r.giftsCompany)}',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(
                              '${{for (final r in rows) ...r.invoiceIds}.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(Fmt.num2(rows.fold<double>(0, (s, r) => s + r.revenue)),
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(Fmt.num2(rows.fold<double>(0, (s, r) => s + r.profit)),
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text('الأرقام بـ $cur', style: const TextStyle(fontSize: 11, color: AppColors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}
