/// Calendar periods for every total in the app. No Flutter imports: rules live here once.
library;

/// A calendar date as yyyymmdd, the form stored in `transactions.local_day`.
int toLocalDay(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Midnight local time on a yyyymmdd day.
DateTime fromLocalDay(int day) => DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100);

/// Midnight local time on the same calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b], ignoring the time of day.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// [d] moved by [days] calendar days, at midnight. Built from the date's parts rather than by
/// adding 24-hour durations, so it stays right in time zones with daylight saving.
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

enum PeriodKind { day, week, month, quarter, year, custom }

/// A run of whole days from [start] (inclusive) to [end] (exclusive), both at midnight.
class Period {
  Period(DateTime start, DateTime end, this.kind) : start = dateOnly(start), end = dateOnly(end) {
    if (!this.end.isAfter(this.start)) {
      throw ArgumentError('A period must end after it starts: $start to $end');
    }
  }

  final DateTime start;
  final DateTime end;
  final PeriodKind kind;

  int get startDay => toLocalDay(start);

  /// The first day after the period, as yyyymmdd, for `local_day < endDay` queries.
  int get endDay => toLocalDay(end);

  /// The last day in the period.
  DateTime get lastDate => addDays(end, -1);
  int get lengthInDays => daysBetween(start, end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  bool containsDay(int localDay) => localDay >= startDay && localDay < endDay;

  @override
  bool operator ==(Object other) =>
      other is Period && other.start == start && other.end == end && other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'Period(${kind.name}, $startDay to $endDay)';
}

/// Works out periods from the "Month starts on" and "Week starts on" settings.
class PeriodCalculator {
  const PeriodCalculator({this.monthStartsOn = 1, this.weekStartsOn = DateTime.sunday})
    : assert(monthStartsOn >= 1 && monthStartsOn <= 28, 'Month start is the 1st to the 28th'),
      assert(weekStartsOn >= DateTime.monday && weekStartsOn <= DateTime.sunday, 'A weekday');

  /// Day of the month a "month" begins on, 1 to 28 (a salary date, say).
  final int monthStartsOn;

  /// [DateTime.monday] to [DateTime.sunday].
  final int weekStartsOn;

  Period of(PeriodKind kind, DateTime date) => switch (kind) {
    PeriodKind.day => day(date),
    PeriodKind.week => week(date),
    PeriodKind.month => month(date),
    PeriodKind.quarter => quarter(date),
    PeriodKind.year => year(date),
    PeriodKind.custom => throw ArgumentError('A custom period has no calendar rule'),
  };

  Period day(DateTime d) => Period(d, DateTime(d.year, d.month, d.day + 1), PeriodKind.day);

  Period week(DateTime d) {
    final back = (d.weekday - weekStartsOn) % 7;
    final start = DateTime(d.year, d.month, d.day - back);
    return Period(start, DateTime(start.year, start.month, start.day + 7), PeriodKind.week);
  }

  /// The month containing [d]: from the latest [monthStartsOn] on or before it.
  /// A month that starts on the 25th of October is named October.
  Period month(DateTime d) {
    final start = d.day >= monthStartsOn
        ? DateTime(d.year, d.month, monthStartsOn)
        : DateTime(d.year, d.month - 1, monthStartsOn);
    return Period(start, DateTime(start.year, start.month + 1, monthStartsOn), PeriodKind.month);
  }

  /// Three months, grouped by the calendar quarter the period's month starts in.
  Period quarter(DateTime d) {
    final m = month(d).start;
    final firstMonth = (m.month - 1) ~/ 3 * 3 + 1;
    final start = DateTime(m.year, firstMonth, monthStartsOn);
    return Period(start, DateTime(start.year, start.month + 3, monthStartsOn), PeriodKind.quarter);
  }

  Period year(DateTime d) {
    final m = month(d).start;
    final start = DateTime(m.year, 1, monthStartsOn);
    return Period(start, DateTime(start.year + 1, 1, monthStartsOn), PeriodKind.year);
  }

  /// The period just before [p], of the same kind.
  Period previous(Period p) {
    if (p.kind == PeriodKind.custom) {
      return Period(addDays(p.start, -p.lengthInDays), p.start, PeriodKind.custom);
    }
    return of(p.kind, addDays(p.start, -1));
  }

  Period next(Period p) {
    if (p.kind == PeriodKind.custom) {
      return Period(p.end, addDays(p.end, p.lengthInDays), PeriodKind.custom);
    }
    return of(p.kind, p.end);
  }

  /// Days of [p] up to and including [today]: 0 before it starts, its length after it ends.
  int elapsedDays(Period p, DateTime today) {
    final n = daysBetween(p.start, today) + 1;
    return n.clamp(0, p.lengthInDays);
  }

  /// The same number of days at the start of the period before [current], for a fair
  /// comparison such as "12% above this point in October". Never longer than that period.
  Period sameDaysOfPrevious(Period current, DateTime today) {
    final prev = previous(current);
    final n = elapsedDays(current, today).clamp(1, prev.lengthInDays);
    return Period(
      prev.start,
      DateTime(prev.start.year, prev.start.month, prev.start.day + n),
      PeriodKind.custom,
    );
  }
}
