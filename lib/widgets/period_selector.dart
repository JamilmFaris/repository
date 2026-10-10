import 'package:flutter/material.dart';
import '../core/utils/period.dart';

/// شريط اختيار الفترة: يوم / أسبوع / شهر / سنة / الكل / بين تاريخين، مع أسهم تنقّل.
class PeriodSelector extends StatefulWidget {
  final PeriodKind initialKind;
  final ValueChanged<PeriodRange> onChanged;
  const PeriodSelector({
    super.key,
    this.initialKind = PeriodKind.month,
    required this.onChanged,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late PeriodKind _kind = widget.initialKind;
  DateTime _anchor = DateTime.now();
  PeriodRange? _custom;

  static const _names = {
    PeriodKind.day: 'يوم',
    PeriodKind.week: 'أسبوع',
    PeriodKind.month: 'شهر',
    PeriodKind.year: 'سنة',
    PeriodKind.all: 'الكل',
    PeriodKind.custom: 'بين تاريخين',
  };

  PeriodRange get _range {
    if (_kind == PeriodKind.custom && _custom != null) return _custom!;
    return PeriodRange.of(_kind, _anchor);
  }

  void _emit() => widget.onChanged(_range);

  Future<void> _select(PeriodKind k) async {
    if (k == PeriodKind.custom) {
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _custom == null
            ? null
            : DateTimeRange(
                start: _custom!.start,
                end: _custom!.end.subtract(const Duration(days: 1))),
      );
      if (r == null) return;
      setState(() {
        _kind = k;
        _custom = PeriodRange(
          PeriodKind.custom,
          DateTime(r.start.year, r.start.month, r.start.day),
          DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1)),
        );
      });
    } else {
      setState(() {
        _kind = k;
        _anchor = DateTime.now();
      });
    }
    _emit();
  }

  void _shift(int dir) {
    setState(() {
      switch (_kind) {
        case PeriodKind.day:
          _anchor = _anchor.add(Duration(days: dir));
        case PeriodKind.week:
          _anchor = _anchor.add(Duration(days: 7 * dir));
        case PeriodKind.month:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case PeriodKind.year:
          _anchor = DateTime(_anchor.year + dir, 1, 1);
        default:
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final canShift = _kind != PeriodKind.all && _kind != PeriodKind.custom;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final k in PeriodKind.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(_names[k]!),
                    selected: _kind == k,
                    onSelected: (_) => _select(k),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (canShift)
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(-1)),
            Text(_range.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (canShift)
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(1)),
          ],
        ),
      ],
    );
  }
}
