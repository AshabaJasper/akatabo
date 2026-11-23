import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';

/// One part of every bar: its name for the legend, and its colour.
class StackPart {
  const StackPart({required this.name, required this.colour});
  final String name;
  final Color colour;
}

/// One bar: the amount of each part, in the order of [StackedBars.parts] (bottom first), the
/// figure over it and the label under it.
class StackColumn {
  const StackColumn({
    required this.values,
    required this.figure,
    required this.label,
    this.current = false,
  });
  final List<int> values;
  final String figure;
  final String label;

  /// The month still running: its figure and label are drawn in `ink` and bold, as drawn.
  final bool current;

  int get total => values.fold(0, (a, b) => a + b);
}

/// Stacked bars with a legend over them, as Fees.html draws its six months: the first part
/// at the bottom, the last on top with rounded corners, a 2px gap between parts, the figure
/// over each bar and the labels under a `line-strong` rule. Heights are scaled to the largest
/// bar. The whole chart is one image for screen readers, read as [semanticLabel].
class StackedBars extends StatelessWidget {
  const StackedBars({
    super.key,
    required this.parts,
    required this.columns,
    required this.semanticLabel,
  });

  final List<StackPart> parts;
  final List<StackColumn> columns;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final largest = columns.fold(0, (m, col) => math.max(m, col.total));
    // The bars take the drawn height less one line of figures, which grows with the text
    // size on top of it, so a large text size never squashes the bars.
    final figureLine = (t.caption.fontSize ?? 12) * (t.caption.height ?? 1.3);
    final barArea = AkSize.chartSm - figureLine - AkSpace.s0h;

    return Semantics(
      image: true,
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AkSpace.s3,
            runSpacing: AkSpace.s1,
            children: [
              for (final p in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AkSize.dot,
                      height: AkSize.dot,
                      decoration: BoxDecoration(
                        color: p.colour,
                        borderRadius: BorderRadius.circular(context.metrics.xs),
                      ),
                    ),
                    const SizedBox(width: AkSpace.s1),
                    Text(p.name, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, col) in columns.indexed) ...[
                if (i > 0) const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: _Bar(column: col, parts: parts, largest: largest, area: barArea),
                ),
              ],
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: AkSpace.s0h),
            padding: const EdgeInsets.only(top: AkSpace.s1),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.lineStrong)),
            ),
            child: Row(
              children: [
                for (final (i, col) in columns.indexed) ...[
                  if (i > 0) const SizedBox(width: AkSpace.s3),
                  Expanded(
                    child: Text(
                      col.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: col.current
                          ? t.caption.copyWith(color: c.ink, fontWeight: FontWeight.w600)
                          : t.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.column,
    required this.parts,
    required this.largest,
    required this.area,
  });

  final StackColumn column;
  final List<StackPart> parts;
  final int largest;
  final double area;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = Radius.circular(context.metrics.sm);
    // Parts with something in them, top first, as a column draws them.
    final shown = [
      for (var i = parts.length - 1; i >= 0; i--)
        if (i < column.values.length && column.values[i] > 0)
          (part: parts[i], value: column.values[i]),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          column.figure,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: column.current
              ? t.caption.copyWith(color: c.ink, fontWeight: FontWeight.w600)
              : t.caption.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s0h),
        for (final (i, s) in shown.indexed) ...[
          if (i > 0) const SizedBox(height: AkSpace.s0h),
          Container(
            key: ValueKey('${column.label}-${s.part.name}'),
            height: largest == 0 ? 0 : math.max(1, area * s.value / largest),
            decoration: BoxDecoration(
              color: s.part.colour,
              borderRadius: i == 0 ? BorderRadius.vertical(top: radius) : null,
            ),
          ),
        ],
      ],
    );
  }
}
