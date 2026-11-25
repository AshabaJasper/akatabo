import 'dart:math' as math;

import '../core/time/period.dart';
import '../data/db/app_database.dart';
import '../data/seed/default_data.dart';
import 'calendar.dart';
import 'spending.dart';

/// The month-end forecast, worked out on the phone from the person's own entries.
///
/// Pure Dart. The rule is written once here (DESIGN_SYSTEM.md, "Rules for the numbers"):
/// spent so far, plus the everyday daily rate times the days left, plus the regular payments
/// still due. One-off payments are left out of the rate, so a school term does not make
/// every day look expensive.

/// Days with at least one entry this month before a forecast is shown at all.
const forecastMinDays = 7;

/// Days of history the everyday rate is worked out from.
const rateWindowDays = 90;

/// Fewest entries in a category before its one-off line is trusted.
const oneOffMinSample = 4;

/// Regular payments can recur only this many times in a month before we stop counting,
/// which guards against an interval of 0 or 1 day in bad data.
const _maxDuesPerPayment = 400;

/// One regular payment still due this month.
class RegularDue {
  const RegularDue({
    required this.label,
    required this.due,
    required this.low,
    required this.typical,
    required this.high,
  });

  final String label;
  final DateTime due;
  final int low;
  final int typical;
  final int high;
}

/// What is left to spend each day until month end, when income is known.
sealed class SafeToSpend {
  const SafeToSpend();
}

/// Money still to spare, shared over the days left.
final class SafeAmount extends SafeToSpend {
  const SafeAmount(this.perDay);
  final int perDay;
}

/// The forecast is above the income: this much more than came in.
final class OverBy extends SafeToSpend {
  const OverBy(this.amount);
  final int amount;
}

/// Income minus the forecast, divided by the days left. Null when no income is recorded
/// this month (there is nothing to measure against) or no day is left to spread it over.
SafeToSpend? safeToSpend({
  required int moneyIn,
  required int forecastPoint,
  required int daysLeft,
}) {
  if (moneyIn <= 0 || daysLeft <= 0) return null;
  final spare = moneyIn - forecastPoint;
  if (spare < 0) return OverBy(-spare);
  return SafeAmount(spare ~/ daysLeft);
}

/// Money out so far this month against the same days last month.
class Pace {
  const Pace({required this.thisMonth, required this.lastMonth});

  final int thisMonth;
  final int lastMonth;

  /// Positive when this month is spending more than it did by now last month.
  int get difference => thisMonth - lastMonth;
}

/// The pace, or null when last month has no spending on those days to compare with.
Pace? paceVsLast({required int thisMonth, required int lastMonth}) =>
    lastMonth <= 0 ? null : Pace(thisMonth: thisMonth, lastMonth: lastMonth);

/// The forecast for one month, as it stands on [today].
class Forecast {
  const Forecast({
    required this.spentSoFar,
    required this.dailyRate,
    required this.daysLeft,
    required this.everydayToCome,
    required this.regularDue,
    required this.point,
    required this.low,
    required this.high,
    this.everydayDaily = const [],
    this.everydayToday = 0,
    this.regularBands = const [],
    this.oneOffs = const {},
  });

  /// Money out this month so far, including fees and tax.
  final int spentSoFar;

  /// The everyday spending per day, in whole shillings, with one-offs and regular payments
  /// taken out.
  final int dailyRate;

  /// Days after today up to the month's last day.
  final int daysLeft;

  /// The everyday spending still to come: the rest of today (the daily rate less what was
  /// already spent today, never below zero), plus [dailyRate] times [daysLeft].
  final int everydayToCome;

  /// Regular payments still due this month, one for each occurrence.
  final int regularDue;

  /// The most likely month-end money out.
  final int point;

  /// The range the month is most likely to land in. Always contains [point]. This is the
  /// Phase 3 first estimate; the screens show the range from `lib/smart/forecast/` instead,
  /// which is worked out from the inputs below.
  final int low;
  final int high;

  /// The everyday spending of each history day, oldest first, with one-offs and regular
  /// payments taken out. Its mean is the daily rate.
  final List<int> everydayDaily;

  /// The everyday part of what was already spent today.
  final int everydayToday;

  /// One band for each regular payment occurrence still due this month, with its name and
  /// due day, so the screen can list them.
  final List<RegularDue> regularBands;

  /// The money-out entries the everyday rate left out as one-offs. They are picked across
  /// the whole rate window, as the rate picks them, so the list matches what was left out.
  final Set<String> oneOffs;
}

/// The window of history the rate is worked out from: [rateWindowDays] days, ending today.
Period rateWindow(DateTime today) => Period(
  addDays(dateOnly(today), -(rateWindowDays - 1)),
  addDays(dateOnly(today), 1),
  PeriodKind.custom,
);

/// The month-end forecast, or null until [forecastMinDays] days this month have entries.
///
/// [monthRows] are this month's entries; [windowRows] are the entries in [rateWindow] (which
/// include [monthRows]'s days); [regular] are the active regular payments.
Forecast? forecastFor({
  required Period month,
  required DateTime today,
  required List<Transaction> monthRows,
  required List<Transaction> windowRows,
  required List<RegularPayment> regular,
}) {
  final daysWithEntries = {for (final t in monthRows) t.localDay}.length;
  if (daysWithEntries < forecastMinDays) return null;

  final now = dateOnly(today);
  final spent = totalsOf(monthRows).moneyOut;
  final daysLeft = daysBetween(now, month.end) - 1;
  final regularKeys = {
    for (final p in regular)
      if (p.payeeKey.isNotEmpty) p.payeeKey,
  };
  final everyday = _everydayRate(windowRows, now, regularKeys);

  // The rest of today counts too: a forecast made in the morning still expects today's spending.
  final todayKey = toLocalDay(now);
  final spentToday = moneyOutByDay(
    _withoutOneOffsAndRegular([
      for (final t in windowRows)
        if (t.localDay == todayKey) t,
    ], regularKeys),
  )[todayKey];
  final restOfToday = math.max(0, everyday.mean - (spentToday ?? 0));
  final toCome = restOfToday + everyday.mean * daysLeft;
  final spread = everyday.sd * math.sqrt(daysLeft + 1);

  var regularDue = 0;
  var regularLow = 0;
  var regularHigh = 0;
  final bands = <RegularDue>[];
  for (final p in regular) {
    var dues = regularDuesIn(p, from: now, through: month.lastDate);
    // A payment due today that is already entered is in "spent so far"; do not add it again.
    if (dues.isNotEmpty && dues.first == now && _paidOn(p, todayKey, monthRows)) {
      dues = dues.sublist(1);
    }
    final occurrences = dues.length;
    regularDue += p.typicalAmount * occurrences;
    regularLow += p.amountLow * occurrences;
    regularHigh += p.amountHigh * occurrences;
    for (final due in dues) {
      bands.add(
        RegularDue(
          label: p.label,
          due: due,
          low: p.amountLow,
          typical: p.typicalAmount,
          high: p.amountHigh,
        ),
      );
    }
  }

  final point = spent + toCome.round() + regularDue;
  final low = math.min(point, spent + math.max(0, toCome - spread).round() + regularLow);
  final high = math.max(point, spent + (toCome + spread).round() + regularHigh);
  return Forecast(
    spentSoFar: spent,
    dailyRate: everyday.mean.round(),
    daysLeft: daysLeft,
    everydayToCome: toCome.round(),
    regularDue: regularDue,
    point: point,
    low: low,
    high: high,
    everydayDaily: everyday.daily,
    everydayToday: spentToday ?? 0,
    regularBands: bands,
    oneOffs: oneOffIds(windowRows),
  );
}

/// Whether an entry for [p] was made on [day]: linked to it, or with the same payee.
bool _paidOn(RegularPayment p, int day, List<Transaction> rows) => rows.any(
  (t) =>
      t.localDay == day &&
      t.direction == Direction.moneyOut &&
      (t.regularPaymentId == p.id || (p.payeeKey.isNotEmpty && t.payeeKey == p.payeeKey)),
);

/// The interval, in days, that the form calls "Monthly". It steps by calendar month.
const monthlyIntervalDays = 30;

/// The interval, in days, that the form calls "Yearly". It steps by calendar year.
const yearlyIntervalDays = 365;

/// Every day a regular payment falls on in [from, through], stepping by its interval from
/// the next due date. Monthly and yearly payments keep their day of the month (clamped to the
/// month's length, so the 31st falls on 28 February and returns to the 31st after), instead of
/// drifting by 30 or 365 days. Empty for an interval that is not a positive number of days.
List<DateTime> regularDuesIn(
  RegularPayment p, {
  required DateTime from,
  required DateTime through,
}) {
  if (p.intervalDays <= 0 || p.dismissed) return const [];
  final anchor = fromLocalDay(p.nextDueOn);
  // A day interval starts counting just before [from], so a payment that started years ago
  // still has its dates within the step limit. Months and years step from the anchor, which
  // keeps the day of the month (a short month moves only that one date).
  final calendar = p.intervalDays == monthlyIntervalDays || p.intervalDays == yearlyIntervalDays;
  final first = calendar ? 0 : math.max(0, daysBetween(anchor, from) ~/ p.intervalDays - 1);
  final dues = <DateTime>[];
  for (var n = first; n < first + _maxDuesPerPayment; n++) {
    final due = switch (p.intervalDays) {
      monthlyIntervalDays => _addMonths(anchor, n),
      yearlyIntervalDays => _addMonths(anchor, 12 * n),
      _ => addDays(anchor, p.intervalDays * n),
    };
    if (due.isAfter(through)) break;
    if (!due.isBefore(from)) dues.add(due);
  }
  return dues;
}

/// [d] moved by [months] calendar months, on the same day or the month's last day if shorter.
DateTime _addMonths(DateTime d, int months) {
  final index = d.month - 1 + months;
  final year = d.year + index ~/ 12;
  final month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(d.day, lastDay));
}

/// The everyday daily rate and how much it varies, over the history window.
class _Everyday {
  const _Everyday(this.mean, this.sd, this.daily);
  final double mean;
  final double sd;
  final List<int> daily;
}

_Everyday _everydayRate(List<Transaction> windowRows, DateTime today, Set<String> regularKeys) {
  final ordinary = _withoutOneOffsAndRegular(windowRows, regularKeys);
  if (windowRows.isEmpty) return const _Everyday(0, 0, []);

  // The history is the window, or less when the person has not been using the app that long.
  // It is never shorter than the forecast's own minimum, so one busy day cannot set the rate.
  final firstDay = windowRows.map((t) => t.localDay).reduce((a, b) => a < b ? a : b);
  final since = daysBetween(fromLocalDay(firstDay), today) + 1;
  final historyDays = math.max(forecastMinDays, math.min(rateWindowDays, since));

  final byDay = moneyOutByDay(ordinary);
  final amounts = <int>[
    for (var i = historyDays - 1; i >= 0; i--) byDay[toLocalDay(addDays(today, -i))] ?? 0,
  ];
  final daily = [for (final a in amounts) a.toDouble()];
  final total = daily.fold<double>(0, (a, b) => a + b);
  final mean = total / historyDays;
  var squares = 0.0;
  for (final x in daily) {
    squares += (x - mean) * (x - mean);
  }
  return _Everyday(mean, math.sqrt(squares / historyDays), amounts);
}

/// The entries that belong in the everyday rate: not a regular payment (linked to one, or
/// paid to the same payee as one), and not a one-off.
List<Transaction> _withoutOneOffsAndRegular(List<Transaction> rows, Set<String> regularKeys) {
  final oneOffs = oneOffIds(rows);
  return [
    for (final t in rows)
      if (t.regularPaymentId == null &&
          !(t.payeeKey.isNotEmpty && regularKeys.contains(t.payeeKey)) &&
          !oneOffs.contains(t.id))
        t,
  ];
}

/// The ids of entries that are one-offs: money out above Q3 + 3 × IQR of the amounts.
///
/// A category with at least [oneOffMinSample] entries uses its own line. A category with fewer
/// (a school term is often the only school entry) uses the line of all money out pooled, so a
/// one-off in a thin category is still caught. With fewer than [oneOffMinSample] entries in
/// all, nothing is a one-off, because a handful of numbers cannot tell a one-off from a habit.
Set<String> oneOffIds(Iterable<Transaction> rows) {
  final out = [
    for (final t in rows)
      if (t.direction == Direction.moneyOut) t,
  ];
  final pooled = _oneOffLine([for (final t in out) t.amount]);
  final byCategory = <String, List<Transaction>>{};
  for (final t in out) {
    byCategory.putIfAbsent(t.categoryId ?? DefaultIds.other, () => []).add(t);
  }
  final ids = <String>{};
  for (final list in byCategory.values) {
    final line = list.length >= oneOffMinSample
        ? _oneOffLine([for (final t in list) t.amount])
        : pooled;
    if (line == null) continue;
    for (final t in list) {
      if (t.amount > line) ids.add(t.id);
    }
  }
  return ids;
}

/// Q3 + 3 × IQR of [amounts], or null with too few amounts to have a line.
///
/// The spread is never taken as less than a quarter of Q3. Fixed fares and airtime amounts
/// often make the middle half identical, an IQR of 0, and then any slightly larger amount
/// (a 3,000 ride among 2,000 ones) would wrongly count as a one-off.
double? _oneOffLine(List<int> amounts) {
  if (amounts.length < oneOffMinSample) return null;
  final sorted = [...amounts]..sort();
  final q1 = _quantile(sorted, 0.25);
  final q3 = _quantile(sorted, 0.75);
  return q3 + 3 * math.max(q3 - q1, q3 / 4);
}

/// The p-th quantile of sorted values, by linear interpolation between neighbours.
double _quantile(List<int> sorted, double p) {
  final h = (sorted.length - 1) * p;
  final lo = h.floor();
  final hi = h.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (h - lo);
}
