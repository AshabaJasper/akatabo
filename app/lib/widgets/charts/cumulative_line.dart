import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/format/money.dart';
import '../../core/theme/ak_motion.dart';
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
    this.incomeLine,
  });

  /// The money-in line, dashed across the chart at what came in. Null leaves it out.
  final Color? incomeLine;

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
    this.pulse,
    this.income,
    this.dayLabelOf,
    this.hideFigures = false,
  }) : super(repaint: pulse);

  final List<double?> actual;
  final List<double>? previous;
  final List<double>? forecast;
  final (double, double)? forecastBand;
  final CumulativeColours colours;
  final TextStyle labelStyle;

  /// 0 to 1 over the today point's one pulse; null on charts with no forecast.
  final Animation<double>? pulse;

  /// What came in this period, drawn as a dashed line when [CumulativeColours.incomeLine] is set.
  final double? income;

  /// The day label under each tick on the x-axis, by index. Null draws no axis.
  final String Function(int index)? dayLabelOf;

  /// Amounts are hidden: the chart keeps its shape but writes no money figures.
  final bool hideFigures;

  static const _gridLines = 3;

  /// The room under the plot for the x-axis labels.
  static const _axisHeight = 18.0;

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
      ?income,
    ].fold<double>(0, math.max);
    final maxY = top <= 0 ? 1.0 : top;

    // The plot sits above the x-axis labels, when there are any.
    final plotH = size.height - (dayLabelOf == null ? 0.0 : _axisHeight);
    double x(int i) => i * size.width / (n - 1);
    double y(double v) => plotH - (v / maxY) * plotH * 0.92 - plotH * 0.04;

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
      // The income line carries its own label; a gridline at the same height does not repeat it.
      if (income == null || (value - income!).abs() > 0.5) {
        label.paint(canvas, Offset(0, gy - label.height - 2));
      }
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
      final fill = Path()..moveTo(x(0), plotH);
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
        ..lineTo(x(lastActual), plotH)
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
      final today = Offset(x(lastActual), y(actual[lastActual]!));
      // The pulse: a ring that grows from the dot and fades, once. At 0 and at 1 it draws
      // nothing, so a still chart and a finished pulse look the same.
      final p = pulse?.value ?? 0;
      if (p > 0 && p < 1) {
        canvas.drawCircle(
          today,
          4 + 10 * p,
          Paint()
            ..color = colours.line.withValues(alpha: 0.35 * (1 - p))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(today, 4, Paint()..color = colours.line);
      // Today's figure sits above the dot, in the line colour and bold. Only beside a forecast:
      // without one, today's total is the top of the chart and its own gridline already says it.
      if (!hideFigures && forecast != null) {
        _centred(
          canvas,
          formatShort(actual[lastActual]!.round()),
          labelStyle.copyWith(color: colours.line, fontWeight: FontWeight.w700),
          Offset(today.dx, today.dy - 16),
          size,
        );
      }
    }

    // Income: a dashed line across at what came in, labelled at the right.
    final incomeColour = colours.incomeLine;
    final incomeValue = income;
    if (incomeColour != null && incomeValue != null && incomeValue > 0) {
      final iy = y(incomeValue);
      _dash(
        canvas,
        Path()
          ..moveTo(0, iy)
          ..lineTo(size.width, iy),
        Paint()
          ..color = incomeColour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
        dash: 6,
        gap: 4,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: hideFigures ? 'Income' : 'Income ${formatShort(incomeValue.round())}',
          style: labelStyle.copyWith(color: incomeColour),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width, iy - tp.height - 2));

      // The first day the forecast reaches the income: where money out passes what came in.
      final k = forecast == null || lastActual < 0 ? null : passesIncomeAt(forecast!, incomeValue);
      if (k != null) {
        final p = Offset(x(lastActual + k), y(forecast![k]));
        canvas.drawCircle(p, 5, Paint()..color = colours.forecast);
        _centred(
          canvas,
          'Passes income',
          labelStyle.copyWith(color: colours.forecast),
          Offset(p.dx, p.dy - 16),
          size,
        );
      }
    }

    // The forecast's end is hollow, so it reads as a guess, not a total.
    if (forecast != null && forecast!.isNotEmpty && lastActual >= 0) {
      final endIndex = math.min(n - 1, lastActual + forecast!.length - 1);
      canvas.drawCircle(
        Offset(x(endIndex), y(forecast!.last)),
        5,
        Paint()
          ..color = colours.forecast
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Day labels under the plot, with today in bold.
    final dayLabel = dayLabelOf;
    if (dayLabel != null) {
      // Every fourth day, but a tick that would sit on top of the last day or today gives way.
      final step = math.max(1, (n - 1) ~/ 4);
      bool crowded(int i) =>
          i != n - 1 &&
          i != lastActual &&
          ((n - 1 - i).abs() < step / 2 || (lastActual >= 0 && (i - lastActual).abs() < step / 2));
      final ticks = <int>{
        for (var i = 0; i < n; i += step)
          if (!crowded(i)) i,
        n - 1,
        if (lastActual >= 0) lastActual,
      };
      for (final i in ticks) {
        final isToday = i == lastActual;
        _centred(
          canvas,
          dayLabel(i),
          isToday
              ? labelStyle.copyWith(color: colours.line, fontWeight: FontWeight.w700)
              : labelStyle,
          Offset(x(i), plotH + _axisHeight / 2),
          size,
        );
      }
    }
  }

  /// Draws [text] centred on [centre], pulled inside the chart's width and height at the edges.
  void _centred(Canvas canvas, String text, TextStyle style, Offset centre, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = math.min(
      math.max<double>(centre.dx - tp.width / 2, 0),
      math.max<double>(0, size.width - tp.width),
    );
    final dy = math.min(
      math.max<double>(centre.dy - tp.height / 2, 0),
      math.max<double>(0, size.height - tp.height),
    );
    tp.paint(canvas, Offset(dx, dy));
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
      old.income != income ||
      old.hideFigures != hideFigures ||
      old.colours != colours ||
      old.pulse != pulse;
}

/// The chart box: the painter at the chart height, with a sentence that says what it shows.
/// With a [forecast], today's point pulses once when the chart first shows, and stays still
/// when the person has asked for less motion.
class CumulativeLineChart extends StatefulWidget {
  const CumulativeLineChart({
    super.key,
    required this.summary,
    required this.actual,
    required this.colours,
    this.previous,
    this.forecast,
    this.forecastBand,
    this.income,
    this.dayLabelOf,
    this.hideFigures = false,
  });

  /// Read aloud instead of the drawing.
  final String summary;
  final List<double?> actual;
  final List<double>? previous;
  final List<double>? forecast;
  final (double, double)? forecastBand;
  final CumulativeColours colours;
  final double? income;
  final String Function(int index)? dayLabelOf;
  final bool hideFigures;

  @override
  State<CumulativeLineChart> createState() => _CumulativeLineChartState();
}

class _CumulativeLineChartState extends State<CumulativeLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AkMotion.pulse,
  );
  late final CurvedAnimation _eased = CurvedAnimation(parent: _pulse, curve: AkMotion.settle);
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once per chart, and never under reduced motion: the dot then simply stays.
    if (!_played && widget.forecast != null && !MediaQuery.disableAnimationsOf(context)) {
      _played = true;
      unawaited(_pulse.forward());
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      label: widget.summary,
      image: true,
      child: SizedBox(
        height: AkSize.chart,
        width: double.infinity,
        child: CustomPaint(
          painter: CumulativeLinePainter(
            actual: widget.actual,
            previous: widget.previous,
            forecast: widget.forecast,
            forecastBand: widget.forecastBand,
            colours: widget.colours,
            labelStyle: t.caption,
            pulse: widget.forecast == null ? null : _eased,
            income: widget.income,
            dayLabelOf: widget.dayLabelOf,
            hideFigures: widget.hideFigures,
          ),
        ),
      ),
    );
  }
}

/// The step along [forecast] (0 is today) where money out first reaches [income], or null
/// when it never does or is there already today: a crossing that has happened is not
/// marked as if it were still to come.
int? passesIncomeAt(List<double> forecast, double income) {
  if (forecast.isEmpty || forecast.first >= income) return null;
  for (var k = 1; k < forecast.length; k++) {
    if (forecast[k] >= income) return k;
  }
  return null;
}
