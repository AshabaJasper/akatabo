import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

/// A dashed rounded outline: something that has not happened yet (a future period on
/// Calendar, later the forecast and empty budget cards). Never filled, so it never reads
/// as a zero.
class AkDashedBox extends StatelessWidget {
  const AkDashedBox({super.key, required this.color, required this.radius, this.child});

  final Color color;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedOutlinePainter(color: color, radius: radius),
    child: child ?? const SizedBox.expand(),
  );
}

class _DashedOutlinePainter extends CustomPainter {
  _DashedOutlinePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = radius.clamp(0, size.shortestSide / 2).toDouble();
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(r)));
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter old) => old.color != color || old.radius != radius;
}
