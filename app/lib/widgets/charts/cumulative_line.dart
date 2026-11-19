import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';

/// The colours a running-total chart draws with. Screens pass theme tokens; nothing here
/// names a colour.
class CumulativeColours {
  const CumulativeColours({
    required this.line,
    required this.fill,
    required this.previous,
    required this.forecast,
    required this.band,
    required this.grid,
  });

  /// This period's running total: the solid line and its light fill.
  final Color line;
  final Color fill;

  /// The previous period's running total: a dashed line.
  final Color previous;

  /// The forecast from today to month's end: a dotted line over a band.
  final Color forecast;
  final Color band;
  final Color grid;
}

/// Running totals by day, with an optional previous period and a forecast.
///
/// [actual] has one entry per day of the period; null for days that have not happened yet.
/// [previous] is the same days last time. [forecast] runs from today to the last day, starting
/// at today's actual value, and [forecastBand] is its low and high at the end.
class CumulativeLinePainter extends CustomPainter {
  CumulativeLinePainter({
    required this.actual,
    required this.colours,
    required this.labelStyle,
    this.previous,
    this.forecast,
    this.forecastBand,
  });

  final List<double?> actual;
  final List<double>? previous;
  final List<double>? forecast;
  final (double, double)? forecastBand;
  final CumulativeColours colours;
  final TextStyle labelStyle;

  static const _gridLines = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final n = actual.length;
    if (n < 2 || size.isEmpty) return;

    final lastActual = actual.lastIndexWhere((v) => v != null);
    final top = [
      for (final v in actual) ?v,
      ...?previous,
      ...?forecast,
      if (forecastBand != null) forecastBand!.$2,
    ].fold<double>(0, math.max);
    final maxY = top <= 0 ? 1.0 : top;

    double x(int i) => i * size.width / (n - 1);
    double y(double v) => size.height - (v / maxY) * size.height * 0.92 - size.height * 0.04;

    // Three labelled gridlines, the top one at the highest figure on the chart.
    final gridPaint = Paint()
      ..color = colours.grid
      ..strokeWidth = 1;
    for (var g = 1; g <= _gridLines; g++) {
      final value = maxY * g / _gridLines;
      final gy = y(value);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
      final label = TextPainter(
        text: TextSpan(text: formatShort(value.round()), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, gy - label.height - 2));
    }

    // The forecast band, from today's total out to the low and high at month's end.
    if (forecastBand != null && lastActual >= 0 && lastActual < n - 1) {
      final band = Path()
        ..moveTo(x(lastActual), y(actual[lastActual]!))
        ..lineTo(x(n - 1), y(forecastBand!.$2))
        ..lineTo(x(n - 1), y(forecastBand!.$1))
        ..close();
      canvas.drawPath(band, Paint()..color = colours.band);
    }

    if (previous != null) {
      final path = Path();
      for (var i = 0; i < n && i < previous!.length; i++) {
        final p = Offset(x(i), y(previous![i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      _dash(
        canvas,
        path,
        Paint()
          ..color = colours.previous
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
        dash: 6,
        gap: 4,
      );
    }

    if (lastActual >= 0) {
      final path = Path();
      final fill = Path()..moveTo(x(0), size.height);
      for (var i = 0; i <= lastActual; i++) {
        final p = Offset(x(i), y(actual[i] ?? 0));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
          fill.lineTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
          fill.lineTo(p.dx, p.dy);
        }
      }
      fill
        ..lineTo(x(lastActual), size.height)
        ..close();
      canvas.drawPath(fill, Paint()..color = colours.fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = colours.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (forecast != null && lastActual >= 0) {
      final path = Path();
      for (var i = lastActual; i < n && i - lastActual < forecast!.length; i++) {
        final v = forecast![i - lastActual];
        final p = Offset(x(i), y(v));
        i == lastActual ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      _dash(
        canvas,
        path,
        Paint()
          ..color = colours.forecast
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
        dash: 0.1,
        gap: 5,
      );
    }

    if (lastActual >= 0 && actual[lastActual] != null) {
      canvas.drawCircle(
        Offset(x(lastActual), y(actual[lastActual]!)),
        4,
        Paint()..color = colours.line,
      );
    }
  }

  /// Draws [path] as dashes of [dash] length with [gap] between them.
  void _dash(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final e = math.min(d + dash, m.length);
        canvas.drawPath(m.extractPath(d, e), paint);
        d = e + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CumulativeLinePainter old) =>
      old.actual != actual ||
      old.previous != previous ||
      old.forecast != forecast ||
      old.forecastBand != forecastBand ||
      old.colours != colours;
}

/// The chart box: the painter at the chart height, with a sentence that says what it shows.
class CumulativeLineChart extends StatelessWidget {
  const CumulativeLineChart({
    super.key,
    required this.summary,
    required this.actual,
    required this.colours,
    this.previous,
    this.forecast,
    this.forecastBand,
  });

  /// Read aloud instead of the drawing.
  final String summary;
  final List<double?> actual;
  final List<double>? previous;
  final List<double>? forecast;
  final (double, double)? forecastBand;
  final CumulativeColours colours;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: summary,
      image: true,
      child: SizedBox(
        height: AkSize.chart,
        width: double.infinity,
        child: CustomPaint(
          painter: CumulativeLinePainter(
            actual: actual,
            previous: previous,
            forecast: forecast,
            forecastBand: forecastBand,
            colours: colours,
            labelStyle: t.caption,
          ),
        ),
      ),
    );
  }
}
