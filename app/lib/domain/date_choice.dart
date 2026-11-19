/// The date choices on Filters: the presets and the custom range. No Flutter imports.
library;

import '../core/time/period.dart';

enum DatePreset { last7Days, thisMonth, lastMonth, last3Months, thisYear, custom }

/// The period a preset covers, counted back from [today]. [DatePreset.custom] has no rule of
/// its own: the person picks its days, so it throws here.
Period presetPeriod(DatePreset preset, DateTime today, PeriodCalculator calc) {
  final thisMonth = calc.month(today);
  return switch (preset) {
    // Today and the six days before it: seven days in all.
    DatePreset.last7Days => Period(addDays(today, -6), addDays(today, 1), PeriodKind.custom),
    DatePreset.thisMonth => thisMonth,
    DatePreset.lastMonth => calc.previous(thisMonth),
    // The month two back, through the end of this month.
    DatePreset.last3Months => Period(
      calc.previous(calc.previous(thisMonth)).start,
      thisMonth.end,
      PeriodKind.custom,
    ),
    DatePreset.thisYear => calc.year(today),
    DatePreset.custom => throw ArgumentError('A custom range is picked by the person'),
  };
}

/// Whole days in an inclusive range from [first] to [last], as the screen counts them.
int inclusiveDays(DateTime first, DateTime last) => daysBetween(first, last) + 1;

/// The first and last day of a custom range after a tap on [day], both inclusive.
///
/// A range of more than one day is replaced: the tap starts a new one-day range there.
/// On a one-day range, a tap before it moves the start and any other tap moves the end. So
/// any range can be reached in two taps, and the end never falls before the start.
///
/// The drawn rule ("a tap before the start moves the start, any later tap moves the end")
/// could never move the start later, so 10 to 15 November could not be picked from 1 to 30
/// November.
({DateTime first, DateTime last}) pickDay(DateTime first, DateTime last, DateTime day) {
  final d = dateOnly(day);
  final f = dateOnly(first);
  final l = dateOnly(last);
  if (f != l) return (first: d, last: d);
  if (d.isBefore(f)) return (first: d, last: l);
  return (first: f, last: d);
}
