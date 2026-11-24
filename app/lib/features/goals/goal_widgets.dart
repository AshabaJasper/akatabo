import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/goals.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_surfaces.dart';
import 'goal_summary.dart';

final _dayFormat = DateFormat('d MMMM yyyy', 'en');

/// A local day (yyyymmdd) written the way the screens show dates: `1 March 2027`.
String dayText(int localDay) => _dayFormat.format(fromLocalDay(localDay));

/// [amount] as `UGX 40,000`, or the hidden-figure dots while "Hide amounts" is on.
String shownUgx(int amount, {required bool hidden}) => hidden ? hiddenFigure : formatUgx(amount);

/// [amount] as `40,000`, or the hidden-figure dots while "Hide amounts" is on.
String shownAmount(int amount, {required bool hidden}) =>
    hidden ? hiddenFigure : formatAmount(amount);

/// "1 week" or "4 weeks".
String weeksText(int weeks) => weeks == 1 ? '1 week' : '$weeks weeks';

/// The icon a goal is drawn with. An unknown name falls back to the Savings icon.
AkIcons goalIcon(String key) => AkIcons.values.asNameMap()[key] ?? AkIcons.wallet;

/// The milestone names the screens use, by percent of the target.
String milestoneName(int percent) => switch (percent) {
  25 => 'Quarter of the way',
  50 => 'Half way there',
  75 => 'Three quarters of the way',
  _ => 'Goal reached',
};

/// The progress bar: a track, a fill to [progress], and a tick at each milestone before 100.
/// Read by screen readers as one figure, so the ticks add nothing spoken.
class GoalBar extends StatelessWidget {
  const GoalBar({
    super.key,
    required this.progress,
    required this.label,
    required this.fill,
    required this.track,
    required this.tick,
    this.height = 10,
  });

  final double progress;
  final String label;
  final Color fill;
  final Color track;
  final Color tick;
  final double height;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      label: label,
      value: '$percent%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + 6,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 3,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: track, borderRadius: radius),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 3,
                    width: width * progress,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fill, borderRadius: radius),
                    ),
                  ),
                  for (final m in goalMilestones.where((m) => m < 100))
                    Positioned(
                      left: width * m / 100 - 1,
                      top: 0,
                      width: 2,
                      height: height + 6,
                      child: ColoredBox(color: tick),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The status of a goal in words, as a small pill. Nothing is shown while the pace is unknown
/// or with no date, so a pill never claims more than the evidence supports.
class GoalStandingChip extends StatelessWidget {
  const GoalStandingChip({super.key, required this.standing});

  final GoalStanding standing;

  @override
  Widget build(BuildContext context) {
    final label = switch (standing) {
      GoalStanding.reached => 'Reached',
      GoalStanding.onPace => 'On pace',
      GoalStanding.behind => 'A little behind',
      GoalStanding.tooEarly || GoalStanding.noDate => null,
    };
    if (label == null) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceSunk,
        borderRadius: BorderRadius.circular(AkRadiusTokens.pill),
      ),
      child: Text(label, style: context.type.captionStrong.copyWith(color: c.ink)),
    );
  }
}

/// The foreground for an icon drawn on a goal's colour: white on dark colours, ink on light.
Color goalIconInk(BuildContext context, Color background) {
  final c = context.colors;
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? c.onBrand : c.ink;
}

/// One goal on the list: its icon, name, saved figure, status, bar and the next step in words.
/// Tapping it opens the goal.
class GoalRow extends ConsumerWidget {
  const GoalRow({super.key, required this.goal, required this.summary, required this.onTap});

  final Goal goal;
  final GoalSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final tile = colourForToken(c, goal.colourToken);
    final pace = switch (summary.standing) {
      GoalStanding.reached => 'Reached on ${dayText(summary.milestoneDays[100]!)}',
      GoalStanding.noDate => 'Add a date to see what it takes each week',
      _ when summary.datePassed =>
        'Date passed. ${shownUgx(summary.remaining, hidden: hidden)} to go',
      _ =>
        summary.weekly == null
            ? 'Add a date to see what it takes each week'
            : '${shownUgx(summary.weekly!, hidden: hidden)} a week to make it by '
                  '${dayText(goal.targetDay!)}',
    };
    return AkCard(
      onTap: onTap,
      semanticLabel: hidden
          ? '${goal.name}, amounts hidden'
          : '${goal.name}, ${formatUgx(summary.saved)} of ${formatUgx(summary.target)} saved',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AkIconTile(
                icon: goalIcon(goal.iconKey),
                background: tile,
                foreground: goalIconInk(context, tile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: t.bodyStrong),
                    Text(
                      '${shownAmount(summary.saved, hidden: hidden)} of '
                      '${shownAmount(summary.target, hidden: hidden)}',
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              GoalStandingChip(standing: summary.standing),
            ],
          ),
          const SizedBox(height: 10),
          GoalBar(
            progress: summary.progress,
            label: '${goal.name} progress',
            fill: c.brandBright,
            track: c.line,
            tick: c.inkMuted,
          ),
          const SizedBox(height: 8),
          Text(pace, style: t.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
