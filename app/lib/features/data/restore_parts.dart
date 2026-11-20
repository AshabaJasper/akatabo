import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/period.dart';

/// The three steps of Restore, as drawn: a bar over each label. The current step's label is
/// in `ink` and bold, finished steps carry a tick, later ones are muted, so the step is
/// never told by colour alone. Screen readers hear one sentence.
class RestoreSteps extends StatelessWidget {
  const RestoreSteps({super.key, required this.current});

  /// 0, 1 or 2.
  final int current;

  static const labels = ['Choose file', 'Check it', 'Restore'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final done = [for (var i = 0; i < current; i++) labels[i]];
    return Semantics(
      label:
          'Step ${current + 1} of 3: ${labels[current]}.'
          '${done.isEmpty ? '' : ' Done: ${done.join(', ')}.'}',
      container: true,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AkSpace.s1h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: AkSpace.s1,
                    decoration: BoxDecoration(
                      color: i <= current ? c.brandBright : c.line,
                      borderRadius: BorderRadius.circular(context.metrics.xs),
                    ),
                  ),
                  const SizedBox(height: AkSpace.s1h),
                  Row(
                    children: [
                      if (i < current) ...[
                        AkIcon(AkIcons.check, color: c.brandText, size: AkSize.iconXs),
                        const SizedBox(width: AkSpace.s1),
                      ],
                      Flexible(
                        child: Text(
                          '${i + 1} ${labels[i]}',
                          style: (i == current ? t.captionStrong : t.caption).copyWith(
                            color: i == current ? c.ink : c.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _dayMonth(int day, {bool year = false}) =>
    DateFormat(year ? 'd MMM y' : 'd MMM').format(fromLocalDay(day));

/// "from 13 to 19 November", "from 30 October to 2 November", "on 19 November".
String describeDayRange(int first, int last) {
  final a = fromLocalDay(first);
  final b = fromLocalDay(last);
  final full = DateFormat('d MMMM');
  final withYear = DateFormat('d MMMM y');
  if (first == last) return 'on ${full.format(a)}';
  if (a.year != b.year) return 'from ${withYear.format(a)} to ${withYear.format(b)}';
  if (a.month == b.month) return 'from ${a.day} to ${full.format(b)}';
  return 'from ${full.format(a)} to ${full.format(b)}';
}

/// The two date ranges on one line of days, as drawn: the backup in blue, this phone in the
/// main colour, each on a `surface-sunk` track, with the first and last day under them.
class RestoreRangeBars extends StatelessWidget {
  const RestoreRangeBars({
    super.key,
    required this.backupFirst,
    required this.backupLast,
    required this.phoneFirst,
    required this.phoneLast,
  });

  final int? backupFirst;
  final int? backupLast;
  final int? phoneFirst;
  final int? phoneLast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final days = [backupFirst, backupLast, phoneFirst, phoneLast].whereType<int>().toList();
    if (days.isEmpty) return const SizedBox.shrink();
    final start = fromLocalDay(days.reduce(math.min));
    final end = fromLocalDay(days.reduce(math.max));
    final span = math.max(1, end.difference(start).inDays);
    final spansYears = start.year != end.year;
    double at(int day) => fromLocalDay(day).difference(start).inDays / span;

    String sentence() {
      String part(String who, int? a, int? b) => a == null || b == null
          ? '$who has no entries.'
          : '$who covers ${describeDayRange(a, b).replaceFirst(RegExp('^(from|on) '), '')}.';
      return '${part('The backup', backupFirst, backupLast)} '
          '${part('This phone', phoneFirst, phoneLast)}';
    }

    Widget bar(String label, int? first, int? last, Color fill) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AkSpace.s1h),
        child: Row(
          children: [
            SizedBox(
              width: _labelWidth(context),
              child: Text(label, style: t.caption.copyWith(color: c.inkMuted)),
            ),
            const SizedBox(width: AkSpace.s2h),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final left = first == null ? 0.0 : at(first) * w;
                  final width = first == null || last == null
                      ? 0.0
                      : math.max(AkSize.bar, (at(last) - at(first)) * w);
                  return Container(
                    height: AkSpace.s3h,
                    decoration: BoxDecoration(
                      color: c.surfaceSunk,
                      borderRadius: BorderRadius.circular(context.metrics.sm),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: math.min(left, w - width)),
                      child: Container(
                        width: width,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(context.metrics.sm),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: sentence(),
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar('Backup', backupFirst, backupLast, c.catBlue),
          bar('This phone', phoneFirst, phoneLast, c.brandBright),
          Padding(
            padding: EdgeInsetsDirectional.only(start: _labelWidth(context) + AkSpace.s2h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dayMonth(toLocalDay(start), year: spansYears),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
                Text(
                  _dayMonth(toLocalDay(end), year: spansYears),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Wide enough for "This phone" at the person's text size, 72 as drawn at the standard one.
  static double _labelWidth(BuildContext context) =>
      AkSize.catCell * context.type.factor * MediaQuery.textScalerOf(context).scale(1);
}

/// One figure over its label, on the page colour inside a card: "398 transactions".
class RestoreStat extends StatelessWidget {
  const RestoreStat({super.key, required this.figure, required this.label});

  final int figure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      label: '$figure $label',
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2h, vertical: AkSpace.s2),
        decoration: BoxDecoration(
          color: c.ground,
          borderRadius: BorderRadius.circular(context.metrics.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(NumberFormat('#,##0').format(figure), style: t.displaySm),
            Text(label, style: t.caption.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// One way to restore, as a large radio card: a 2px selected outline in `brand-bright`, a
/// 1px `line-strong` one otherwise, and a drawn radio that fills when chosen.
class RestoreChoice extends StatelessWidget {
  const RestoreChoice({
    super.key,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  /// The detail says what would be lost, in `money-out` and bold.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title. $detail',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? BorderSide(color: c.brandBright, width: AkSize.stroke)
              : BorderSide(color: c.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSize.row + AkSpace.s2),
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h, vertical: AkSpace.s2h),
            child: Row(
              children: [
                _Radio(selected: selected),
                const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.bodyStrong),
                      Text(
                        detail,
                        style: warning
                            ? t.captionStrong.copyWith(color: c.moneyOut)
                            : t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: AkSize.iconNav,
      height: AkSize.iconNav,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.brandBright : c.lineStrong, width: AkSize.stroke),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: AkSize.dot,
              height: AkSize.dot,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandBright),
            )
          : null,
    );
  }
}

/// A card that says what went wrong and offers a way on: an alert tile, a title, plain
/// words, and an action below. Not drawn; built from the card and colour rules.
class RestoreProblemCard extends StatelessWidget {
  const RestoreProblemCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AkSpace.s3h),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(context.metrics.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AkSize.tile,
              height: AkSize.tile,
              decoration: BoxDecoration(
                color: c.moneyOutSoft,
                borderRadius: BorderRadius.circular(context.metrics.md),
              ),
              alignment: Alignment.center,
              child: AkIcon(AkIcons.alert, color: c.moneyOut),
            ),
            const SizedBox(width: AkSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(title, style: t.title)),
                  const SizedBox(height: AkSpace.s1),
                  Text(body, style: t.bodySm.copyWith(color: c.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
