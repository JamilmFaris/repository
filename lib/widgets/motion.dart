import 'package:flutter/material.dart';

/// ظهور ناعم لعناصر القوائم: انزلاق لطيف مع تلاشٍ، بتأخير بسيط حسب الترتيب.
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index > 8 ? 8 : index) * 40;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

/// يُكبَّر العنصر قليلاً عند الضغط ثم يعود.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  double _s = 1;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _s = 1.04),
      onPointerUp: (_) => setState(() => _s = 1),
      onPointerCancel: (_) => setState(() => _s = 1),
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// دائرة بالحرف الأول بلون ثابت مشتق من الاسم.
class PartyAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const PartyAvatar({super.key, required this.name, this.radius = 22});

  static const _colors = [
    Color(0xFF2563EB), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF59E0B),
    Color(0xFFEC4899), Color(0xFF0D9488), Color(0xFFEF4444), Color(0xFF475569),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '؟' : trimmed.characters.first;
    final sum = trimmed.runes.fold<int>(0, (a, b) => a + b);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colors[sum % _colors.length],
      child: Text(letter,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.9)),
    );
  }
}

/// بطاقة قائمة بشريط لوني رفيع يدل على الحالة (يمين البطاقة في RTL).
class StatusCard extends StatelessWidget {
  final Color statusColor;
  final Widget child;
  const StatusCard({super.key, required this.statusColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: statusColor),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
