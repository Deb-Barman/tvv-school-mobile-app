import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'insta.dart';

/// The big gradient card at the top of a page (same in light and dark, so white text is always readable).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  static const colors = [Color(0xFF4B36A8), Color(0xFF7B4FD8), Color(0xFFC2379D)];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: const [BoxShadow(color: Color(0x335B3FD6), blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
    );
  }
}

/// A white progress ring with the value in the middle, for use on a [HeroCard].
class HeroRing extends StatelessWidget {
  const HeroRing({super.key, required this.percent, required this.label, this.sub = '', this.size = 112});
  final double percent;
  final String label;
  final String sub;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HeroRingPainter((percent / 100).clamp(0, 1).toDouble()),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: size * 0.22, fontWeight: FontWeight.w800)),
            if (sub.isNotEmpty) Text(sub, style: TextStyle(color: const Color(0xCCFFFFFF), fontSize: size * 0.1)),
          ]),
        ),
      ),
    );
  }
}

class _HeroRingPainter extends CustomPainter {
  _HeroRingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.095;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0x33FFFFFF);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_HeroRingPainter old) => old.value != value;
}

/// A small translucent chip for use on a [HeroCard].
class HeroChip extends StatelessWidget {
  const HeroChip(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0x29FFFFFF), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 5)],
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

/// "Smart tip" card: a coloured icon, a bold line and a short explanation.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.icon, required this.title, required this.text, this.tone = 'accent'});
  final IconData icon;
  final String title;
  final String text;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final col = c.tone(tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: col.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(icon, color: col, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: c.bodyStrong),
            const SizedBox(height: 2),
            Text(text, style: c.small.copyWith(color: c.text.withValues(alpha: 0.8), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

/// A simple bar chart: one bar per entry (value 0-100, null = no data), coloured by [toneOf].
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.labels, required this.toneOf, this.height = 96, this.captions});
  final List<double?> values;
  final List<String> labels;
  final String Function(double) toneOf;
  final double height;

  /// Optional text above each bar (for example "72%").
  final List<String>? captions;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(values[i] == null ? '' : (captions != null ? captions![i] : '${values[i]!.round()}%'),
                  maxLines: 1, style: c.small.copyWith(fontSize: 11, color: c.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SizedBox(
                height: height,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: values[i] == null ? 0 : (values[i]! / 100).clamp(0.04, 1).toDouble()),
                    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                      height: height * v,
                      decoration: BoxDecoration(
                        color: values[i] == null ? c.inset : c.tone(toneOf(values[i]!)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i], maxLines: 2, textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 10.5, height: 1.15)),
            ]),
          ),
        ),
    ]);
  }
}
