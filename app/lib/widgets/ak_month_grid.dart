import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import '../core/time/period.dart';

final _spokenDay = DateFormat('EEEE d MMMM yyyy');

/// Days and steps that cannot be chosen: muted ink, faded further but still readable.
Color fadedInk(AkColorTokens c) => c.inkMuted.withValues(alpha: 0.6);

/// One month as a grid of days, weeks starting on the person's chosen day, with a step back
/// and a step forward. Days from [first] to [last] are tinted and the two ends are filled; a
/// single chosen day is a range of one. Days before [earliest] or after [latest] are faded
/// and cannot be tapped. [today] gets a ring when it is not chosen.
///
/// Used by Choose dates (a range) and by the date dialog (one day). Every glyph is an
/// [AkIcon], so nothing depends on an icon font.
class AkMonthGrid extends StatelessWidget {
  const AkMonthGrid({
    super.key,
    required this.month,
    required this.first,
    required this.last,
    required this.weekStartsOn,
    required this.onTapDay,
    this.onPrevious,
    this.onNext,
    this.earliest,
    this.latest,
    this.today,
  });

  /// Any day in the month shown.
  final DateTime month;
  final DateTime first;
  final DateTime last;

  /// [DateTime.monday] to [DateTime.sunday].
  final int weekStartsOn;
  final ValueChanged<DateTime> onTapDay;

  /// Null greys out the step, as at the earliest or latest month allowed.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final DateTime? earliest;
  final DateTime? latest;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final lead = (DateTime(month.year, month.month).weekday - weekStartsOn) % 7;
    final count = daysInMonth(month.year, month.month);
    final from = dateOnly(first);
    final to = dateOnly(last);
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++)
        _DayCell(
          day: DateTime(month.year, month.month, d),
          first: from,
          last: to,
          today: today == null ? null : dateOnly(today!),
          enabled: _allowed(DateTime(month.year, month.month, d)),
          onTap: onTapDay,
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _StepButton(label: 'Previous month', onTap: onPrevious, back: true),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: t.bodyStrong.copyWith(color: c.ink),
                ),
              ),
            ),
            _StepButton(label: 'Next month', onTap: onNext),
          ],
        ),
        const SizedBox(height: AkSpace.s2),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    // 1 November 2026 is a Sunday; this names each weekday from the chosen start.
                    DateFormat('EEEEE').format(DateTime(2026, 11, 1 + (weekStartsOn + i) % 7)),
                    textAlign: TextAlign.center,
                    style: t.captionStrong.copyWith(color: c.inkMuted),
                  ),
                ),
            ],
          ),
        ),
        for (var r = 0; r < cells.length; r += 7)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: SizedBox(height: AkSize.target, child: cells[r + i]),
                ),
            ],
          ),
      ],
    );
  }

  bool _allowed(DateTime day) =>
      (earliest == null || !day.isBefore(dateOnly(earliest!))) &&
      (latest == null || !day.isAfter(dateOnly(latest!)));
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.first,
    required this.last,
    required this.today,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final DateTime first;
  final DateTime last;
  final DateTime? today;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final isEnd = day == first || day == last;
    final inRange = !day.isBefore(first) && !day.isAfter(last);
    final isToday = day == today;
    final radius = BorderRadius.circular(context.metrics.md);
    final ink = !enabled
        ? fadedInk(c)
        : isEnd
        ? c.onBrand
        : isToday
        ? c.brandText
        : c.ink;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: inRange,
      label: isToday ? 'Today, ${_spokenDay.format(day)}' : _spokenDay.format(day),
      container: true,
      excludeSemantics: true,
      onTap: enabled ? () => onTap(day) : null,
      child: InkResponse(
        onTap: enabled ? () => onTap(day) : null,
        radius: AkSize.target / 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isEnd ? c.brand : (inRange ? c.rangeBand : null),
            borderRadius: radius,
            border: isToday && !isEnd ? Border.all(color: c.brand) : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${day.day}', style: t.bodyMd.copyWith(color: ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap, this.back = false});

  final String label;
  final VoidCallback? onTap;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glyph = AkIcon(
      AkIcons.chevron,
      color: onTap == null ? fadedInk(c) : c.ink,
      size: AkSize.iconSm,
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AkSize.target / 2,
        child: SizedBox.square(
          dimension: AkSize.target,
          child: Center(child: back ? RotatedBox(quarterTurns: 2, child: glyph) : glyph),
        ),
      ),
    );
  }
}
