import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';

/// One payment on the timeline: its day, amount and category colour.
class TimelineBubble {
  const TimelineBubble({required this.day, required this.amount, required this.colour});
  final DateTime day;
  final int amount;
  final Color colour;
}

/// What is due from today to the end of the month as circles on a line, as Upcoming.html
/// draws it: today a small `ink` dot at the left, the month's last day at the right, each
/// payment a circle at its day whose area follows its amount (the largest 17px across the
/// radius), its short figure above and its day under. The whole of it is one image for
/// screen readers, read as [semanticLabel].
class BubbleTimeline extends StatelessWidget {
  const BubbleTimeline({
    super.key,
    required this.from,
    required this.through,
    required this.bubbles,
    required this.endLabel,
    required this.semanticLabel,
    this.hidden = false,
  });

  final DateTime from;
  final DateTime through;
  final List<TimelineBubble> bubbles;

  /// Under the right end: "30 Nov".
  final String endLabel;
  final String semanticLabel;

  /// Hide amounts: the circles stay, their figures do not.
  final bool hidden;

  /// The drawn viewBox is 314 by 86; the line sits at 52.
  static const height = AkSize.chartSm * 86 / 116;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      image: true,
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
        width: double.infinity,
        child: CustomPaint(
          painter: _TimelinePainter(
            from: from,
            through: through,
            bubbles: bubbles,
            endLabel: endLabel,
            hidden: hidden,
            line: c.lineStrong,
            today: c.ink,
            figure: t.caption.copyWith(color: c.ink, fontWeight: FontWeight.w600),
            label: t.caption.copyWith(color: c.inkMuted),
            scaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.from,
    required this.through,
    required this.bubbles,
    required this.endLabel,
    required this.hidden,
    required this.line,
    required this.today,
    required this.figure,
    required this.label,
    required this.scaler,
  });

  final DateTime from;
  final DateTime through;
  final List<TimelineBubble> bubbles;
  final String endLabel;
  final bool hidden;
  final Color line;
  final Color today;
  final TextStyle figure;
  final TextStyle label;
  final TextScaler scaler;

  static const _maxRadius = 17.0;
  static const _minRadius = 5.0;
  static const _inset = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    TextPainter text(String s, TextStyle style) => TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    final under = text('Today', label);
    final lineY = size.height - under.height - _maxRadius - AkSpace.s1;
    const left = _inset;
    final right = size.width - _inset;
    final span = through.difference(from).inDays;
    double xOf(DateTime d) =>
        span <= 0 ? left : left + (right - left) * d.difference(from).inDays / span;

    canvas.drawLine(
      Offset(left, lineY),
      Offset(right, lineY),
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(left, lineY), _minRadius, Paint()..color = today);

    final end = text(endLabel, label);
    final largest = bubbles.fold(0, (m, b) => math.max(m, b.amount));
    // Largest first, so a small payment on a near day is drawn over a big one, not hidden.
    final order = [...bubbles]..sort((a, b) => b.amount.compareTo(a.amount));
    for (final b in order) {
      final r = largest == 0
          ? _minRadius
          : math.max(_minRadius, _maxRadius * math.sqrt(b.amount / largest));
      final x = xOf(b.day);
      canvas.drawCircle(Offset(x, lineY), r, Paint()..color = b.colour);
      if (!hidden) {
        final f = text(formatShort(b.amount), figure);
        f.paint(canvas, Offset(x - f.width / 2, lineY - r - f.height - 1));
      }
      // The day under it, unless it would sit on "Today" or the month's end, which already
      // name that day.
      final d = text('${b.day.day}', label);
      final dx = x - d.width / 2;
      if (dx > under.width + AkSpace.s1 && dx + d.width < size.width - end.width - AkSpace.s1) {
        d.paint(canvas, Offset(dx, size.height - d.height));
      }
    }
    under.paint(canvas, Offset(0, size.height - under.height));
    end.paint(canvas, Offset(size.width - end.width, size.height - end.height));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.bubbles != bubbles ||
      old.from != from ||
      old.through != through ||
      old.hidden != hidden ||
      old.line != line ||
      old.figure != figure ||
      old.scaler != scaler;
}
