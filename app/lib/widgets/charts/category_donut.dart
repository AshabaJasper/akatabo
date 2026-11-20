import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';

/// One slice: its amount and colour. The name goes into the chart's spoken label.
class DonutSlice {
  const DonutSlice({required this.name, required this.amount, required this.colour});
  final String name;
  final int amount;
  final Color colour;
}

/// The share of money out by category as a gapped donut, the total stacked in the centre,
/// as Categories.html draws it: a 150px chart in a 160 box, ring radius 62 and width 24,
/// slices clockwise from the top with a 0.8% gap. Callers pass at most six slices.
///
/// fl_chart reads nothing aloud, so the whole chart is one image with [semanticLabel].
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centre,
    required this.centreCaption,
    required this.semanticLabel,
  });

  final List<DonutSlice> slices;
  final String centre;
  final String centreCaption;
  final String semanticLabel;

  /// The drawn width against the 160 viewBox.
  static const size = AkSize.chart * 150 / 160;
  static const _ringWidth = size * 24 / 160;
  static const _ringMiddle = size * 62 / 160;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final still = MediaQuery.disableAnimationsOf(context);
    const gap = 2 * math.pi * _ringMiddle * 0.008;
    // The inside of the ring, less a small margin so text never touches it.
    const hole = (_ringMiddle - _ringWidth / 2) * 2 - AkSpace.s2;
    return Semantics(
      image: true,
      label: semanticLabel,
      container: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: gap,
                centerSpaceRadius: _ringMiddle - _ringWidth / 2,
                centerSpaceColor: c.ground.withValues(alpha: 0),
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final s in slices)
                    if (s.amount > 0)
                      PieChartSectionData(
                        value: s.amount.toDouble(),
                        color: s.colour,
                        radius: _ringWidth,
                        showTitle: false,
                      ),
                ],
              ),
              duration: still ? Duration.zero : const Duration(milliseconds: 550),
            ),
            // Large text or a long total shrinks to fit the hole instead of running over
            // the ring.
            SizedBox.square(
              dimension: hole,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centre, style: t.headline.copyWith(color: c.ink)),
                    Text(centreCaption, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
