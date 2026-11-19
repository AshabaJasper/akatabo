/// The Calendar's numbers: money out per day, hour, week and month, which marks are past,
/// current or still to come, and how dark a day is on the heat grid. No Flutter here.
library;

import '../core/time/period.dart';
import '../data/db/app_database.dart';
import 'spending.dart';

/// Whether a mark on the Calendar has happened. The current one is drawn darkest and the
/// ones still to come are outlines, never zeros.
enum MarkState { past, current, future }

/// One bar or cell: a run of time from [start] (inclusive) to [end] (exclusive).
class CalendarMark {
  const CalendarMark({
    required this.start,
    required this.end,
    required this.moneyOut,
    required this.state,
  });

  final DateTime start;
  final DateTime end;
  final int moneyOut;
  final MarkState state;

  @override
  String toString() => 'CalendarMark($start, $moneyOut, ${state.name})';
}

/// Where [start, end) sits relative to [now]. Past once [now] has reached its end.
MarkState stateOf(DateTime start, DateTime end, DateTime now) {
  if (!now.isBefore(end)) return MarkState.past;
  if (!now.isBefore(start)) return MarkState.current;
  return MarkState.future;
}

/// An hour with an entry in it has happened, even if [now] is behind; the current hour
/// stays current.
MarkState _happenedIfSpent(MarkState state, int moneyOut) =>
    state == MarkState.future && moneyOut > 0 ? MarkState.past : state;

/// Money out on each day (yyyymmdd) of [rows]. Days with none are absent.
Map<int, int> moneyOutByDay(Iterable<Transaction> rows) {
  final out = <int, int>{};
  for (final tx in rows) {
    final m = moneyOutOf(tx);
    if (m > 0) out.update(tx.localDay, (v) => v + m, ifAbsent: () => m);
  }
  return out;
}

int _sumDays(Map<int, int> byDay, DateTime start, DateTime end) {
  final from = toLocalDay(start);
  final to = toLocalDay(end);
  var sum = 0;
  for (final e in byDay.entries) {
    if (e.key >= from && e.key < to) sum += e.value;
  }
  return sum;
}

/// One mark per day of [period] (a week or a month).
List<CalendarMark> dayMarks(Period period, Map<int, int> byDay, DateTime now) => [
  for (var d = period.start; d.isBefore(period.end); d = addDays(d, 1))
    CalendarMark(
      start: d,
      end: addDays(d, 1),
      moneyOut: byDay[toLocalDay(d)] ?? 0,
      state: stateOf(d, addDays(d, 1), now),
    ),
];

/// One mark per hour of [day], from the time each entry happened.
List<CalendarMark> hourMarks(DateTime day, Iterable<Transaction> rows, DateTime now) {
  final perHour = List<int>.filled(24, 0);
  final key = toLocalDay(day);
  for (final tx in rows) {
    if (tx.localDay == key) perHour[tx.occurredAt.hour] += moneyOutOf(tx);
  }
  final midnight = dateOnly(day);
  return [
    for (var h = 0; h < 24; h++)
      CalendarMark(
        start: DateTime(midnight.year, midnight.month, midnight.day, h),
        end: DateTime(midnight.year, midnight.month, midnight.day, h + 1),
        moneyOut: perHour[h],
        state: _happenedIfSpent(
          stateOf(
            DateTime(midnight.year, midnight.month, midnight.day, h),
            DateTime(midnight.year, midnight.month, midnight.day, h + 1),
            now,
          ),
          perHour[h],
        ),
      ),
  ];
}

/// One mark per week that starts inside [quarter], cut to the quarter's edges, so the
/// weeks add up to the quarter's total. Weeks start on the person's "Week starts on".
List<CalendarMark> weekMarks(
  Period quarter,
  Map<int, int> byDay,
  DateTime now,
  PeriodCalculator calc,
) {
  final marks = <CalendarMark>[];
  var start = quarter.start;
  while (start.isBefore(quarter.end)) {
    final weekEnd = calc.week(start).end;
    final end = weekEnd.isAfter(quarter.end) ? quarter.end : weekEnd;
    marks.add(
      CalendarMark(
        start: start,
        end: end,
        moneyOut: _sumDays(byDay, start, end),
        state: stateOf(start, end, now),
      ),
    );
    start = end;
  }
  return marks;
}

/// One mark per month of [year], using "Month starts on".
List<CalendarMark> monthMarks(
  Period year,
  Map<int, int> byDay,
  DateTime now,
  PeriodCalculator calc,
) {
  final marks = <CalendarMark>[];
  var month = calc.month(year.start);
  while (month.start.isBefore(year.end)) {
    marks.add(
      CalendarMark(
        start: month.start,
        end: month.end,
        moneyOut: _sumDays(byDay, month.start, month.end),
        state: stateOf(month.start, month.end, now),
      ),
    );
    month = calc.next(month);
  }
  return marks;
}

/// How dark a day is on the month grid, 0 (least) to 3 (most).
///
/// By rank among the days that have happened, not by size: one 398,000 school-fees day
/// would otherwise leave every other day in the lightest step. The cut points (above 40%,
/// 75% and 92% of days) reproduce the drawn November exactly, and put about two days a
/// month in the darkest step.
int heatStep(int amount, Iterable<int> daysSoFar) {
  if (amount <= 0) return 0;
  final spent = daysSoFar.where((v) => v > 0).toList();
  if (spent.isEmpty) return 0;
  final atOrBelow = spent.where((v) => v <= amount).length;
  final rank = atOrBelow / spent.length;
  if (rank > 0.92) return 3;
  if (rank > 0.75) return 2;
  if (rank > 0.40) return 1;
  return 0;
}

/// The highest, lowest and usual month of a year, from months that have ended.
class YearSummary {
  const YearSummary({required this.highest, required this.lowest, required this.usual});

  final CalendarMark highest;
  final CalendarMark lowest;

  /// The median month's money out.
  final int usual;
}

/// Null until two months have ended: one month has no highest, lowest or usual.
///
/// Months before the first one with money out are left out: they are before the person
/// started using the app, not months in which they spent nothing.
YearSummary? summariseYear(List<CalendarMark> months) {
  final first = months.indexWhere((m) => m.moneyOut > 0);
  if (first < 0) return null;
  final ended = months.skip(first).where((m) => m.state == MarkState.past).toList();
  if (ended.length < 2) return null;
  final sorted = [...ended]..sort((a, b) => a.moneyOut.compareTo(b.moneyOut));
  final mid = sorted.length ~/ 2;
  final usual = sorted.length.isOdd
      ? sorted[mid].moneyOut
      : ((sorted[mid - 1].moneyOut + sorted[mid].moneyOut) / 2).round();
  return YearSummary(highest: sorted.last, lowest: sorted.first, usual: usual);
}
