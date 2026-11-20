/// The month-end forecast RANGE, worked out on the phone. Pure Dart: no Flutter, no database.
///
/// This is the port of `ml/forecast/range.py`. A parity test
/// (`test/smart/forecast_parity_test.dart`) feeds both the same vectors and requires the same
/// low, point and high, so what was backtested in Python is what runs here. Change one,
/// change the other, then run `python -m forecast.export` from `ml/`.
///
/// The point is the Phase 3 rule (`lib/domain/forecast.dart`), unchanged: spent so far, plus
/// `max(0, mean - spent today) + mean × days left` rounded, plus the typical amount of every
/// regular payment still due, where `mean` is the average everyday daily amount.
///
/// The range:
/// 1. **Bootstrap.** [forecastSamples] simulated months. Each draws one history day for the
///    rest of today (only what is above what was already spent today, never below zero) and
///    one history day for each day left, with replacement, and adds them up.
/// 2. **Cut-offs.** The 10th and 90th percentiles of the simulated totals (an 80% range), by
///    linear interpolation on the sorted totals ([percentile]).
/// 3. **Regular payments.** Low adds each due payment's low amount, high its high amount.
/// 4. **The person's own track record.** Each earlier month with a saved snapshot gives one
///    error, `(actual - snapshot point) / snapshot point`, from its snapshot nearest the same
///    day of the month ([snapshotErrors]). With `k` months (newest [forecastMaxMonths]) and
///    weight `w = k / (k + forecastShrinkMonths)`, each edge relative to the point moves out
///    toward the 10th or 90th percentile of the errors when they went beyond it, never in.
///    No snapshot months, or a point of 0: no adjustment.
/// 5. **Clamp.** Low is at least the money already spent and at most the point; high is at
///    least the point.
///
/// The random draws come from a fixed 32-bit xorshift ([Xorshift32]) seeded from the day of
/// the month, so the same inputs on the same day always give the same range, here and in
/// Python.
library;

import 'dart:math' as math;

/// The fixed seed constant of the xorshift (the golden ratio's 32-bit fraction).
const forecastSeed = 0x9E3779B9;

/// Simulated months in the bootstrap.
const forecastSamples = 500;

/// The range's cut-offs: the 10th and 90th percentiles, an 80% range.
const forecastPercentileLow = 0.1;
const forecastPercentileHigh = 0.9;

/// Months of the person's own errors at which they carry half the weight.
const forecastShrinkMonths = 3;

/// The newest months of errors that count.
const forecastMaxMonths = 12;

const _mask32 = 0xFFFFFFFF;

/// Marsaglia's 32-bit xorshift with shifts 13, 17 and 5.
///
/// ```text
/// state = (forecastSeed XOR dayOfMonth) AND 0xFFFFFFFF; if state == 0 then state = forecastSeed
/// next:   x ^= (x << 13) & 0xFFFFFFFF;  x ^= x >> 17;  x ^= (x << 5) & 0xFFFFFFFF
/// index = x mod n
/// ```
///
/// Written with 64-bit ints and a 32-bit mask, as on Android and iOS. (Web ints would differ.)
class Xorshift32 {
  Xorshift32.forDay(int dayOfMonth) : _state = _seedFor(dayOfMonth);

  int _state;

  static int _seedFor(int dayOfMonth) {
    final s = (forecastSeed ^ dayOfMonth) & _mask32;
    return s == 0 ? forecastSeed : s;
  }

  /// The next state, from 1 to 2^32 - 1.
  int next() {
    var x = _state;
    x ^= (x << 13) & _mask32;
    x ^= x >> 17;
    x ^= (x << 5) & _mask32;
    return _state = x;
  }
}

/// `floor(x + 0.5)`, written the same way in Python, so both round alike.
int roundHalfUp(double x) => (x + 0.5).floor();

/// The [p]-th percentile of already sorted [sorted], by linear interpolation between the two
/// nearest ranks: `h = (n - 1) × p`. 0 for an empty list.
double percentile(List<num> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final h = (sorted.length - 1) * p;
  final lo = h.floor();
  final hi = h.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (h - lo);
}

/// One regular payment occurrence still due this month.
class RegularBand {
  const RegularBand({required this.low, required this.typical, required this.high});

  final int low;
  final int typical;
  final int high;
}

/// The forecast and the range it most likely lands in.
class ForecastRange {
  const ForecastRange({
    required this.low,
    required this.point,
    required this.high,
    required this.everydayLow,
    required this.everydayHigh,
    required this.monthsUsed,
  });

  final int low;
  final int point;
  final int high;

  /// The 10th and 90th percentiles of the simulated everyday spending still to come.
  final double everydayLow;
  final double everydayHigh;

  /// Earlier months whose saved forecasts adjusted the range; 0 when none did.
  final int monthsUsed;
}

/// [forecastSamples] simulated everyday totals for the rest of the month, unsorted.
List<int> bootstrapTotals({
  required List<int> daily,
  required int spentToday,
  required int daysLeft,
  required int dayOfMonth,
}) {
  final n = daily.length;
  if (n == 0) return const [];
  final rng = Xorshift32.forDay(dayOfMonth);
  return [for (var k = 0; k < forecastSamples; k++) _oneMonth(daily, n, rng, spentToday, daysLeft)];
}

int _oneMonth(List<int> daily, int n, Xorshift32 rng, int spentToday, int daysLeft) {
  var total = math.max(0, daily[rng.next() % n] - spentToday);
  for (var j = 0; j < daysLeft; j++) {
    total += daily[rng.next() % n];
  }
  return total;
}

/// The month-end forecast and its 80% range from plain inputs.
///
/// [everydayDaily] is the person's everyday spending per history day (one-offs and regular
/// payments out); [spentToday] is the everyday part already spent today; [daysLeft] counts the
/// days after today; [regular] has one band per regular payment still due; [snapshotErrors]
/// come from [snapshotErrors], newest month first.
ForecastRange forecastRange({
  required int spentSoFar,
  required List<int> everydayDaily,
  required int spentToday,
  required int daysLeft,
  required List<RegularBand> regular,
  required int dayOfMonth,
  List<double> snapshotErrors = const [],
}) {
  final n = everydayDaily.length;
  final mean = n == 0 ? 0.0 : everydayDaily.fold<int>(0, (a, b) => a + b) / n;
  final toCome = math.max(0.0, mean - spentToday) + mean * daysLeft;
  var regLow = 0;
  var regTypical = 0;
  var regHigh = 0;
  for (final r in regular) {
    regLow += r.low;
    regTypical += r.typical;
    regHigh += r.high;
  }
  final point = spentSoFar + roundHalfUp(toCome) + regTypical;

  final sims = bootstrapTotals(
    daily: everydayDaily,
    spentToday: spentToday,
    daysLeft: daysLeft,
    dayOfMonth: dayOfMonth,
  ).toList()..sort();
  final evLow = sims.isEmpty ? toCome : percentile(sims, forecastPercentileLow);
  final evHigh = sims.isEmpty ? toCome : percentile(sims, forecastPercentileHigh);

  var low = spentSoFar + roundHalfUp(evLow) + regLow;
  var high = spentSoFar + roundHalfUp(evHigh) + regHigh;
  final used = math.min(snapshotErrors.length, forecastMaxMonths);
  if (used > 0 && point > 0) {
    final w = used / (used + forecastShrinkMonths);
    final loRel = (low - point) / point;
    final hiRel = (high - point) / point;
    final errors = snapshotErrors.sublist(0, used).toList()..sort();
    final loRel2 = loRel + w * math.min(0.0, percentile(errors, forecastPercentileLow) - loRel);
    final hiRel2 = hiRel + w * math.max(0.0, percentile(errors, forecastPercentileHigh) - hiRel);
    low = roundHalfUp(point * (1 + loRel2));
    high = roundHalfUp(point * (1 + hiRel2));
  }

  low = math.min(math.max(low, spentSoFar), point);
  high = math.max(high, point);
  return ForecastRange(
    low: low,
    point: point,
    high: high,
    everydayLow: evLow,
    everydayHigh: evHigh,
    monthsUsed: point > 0 ? used : 0,
  );
}

/// A saved forecast for an earlier month, with what that month really came to.
class SnapshotPoint {
  const SnapshotPoint({
    required this.periodStart,
    required this.dayInPeriod,
    required this.point,
    required this.actual,
  });

  /// The month's first day, yyyymmdd.
  final int periodStart;

  /// 1 on the month's first day.
  final int dayInPeriod;
  final int point;
  final int actual;
}

/// One relative error per earlier month, newest month first, at most [forecastMaxMonths].
///
/// Each month uses its snapshot taken nearest [dayInPeriod] (the earlier day on a tie). A
/// snapshot with a point of 0 or less says nothing about relative error and is skipped.
List<double> snapshotErrors(List<SnapshotPoint> snapshots, {required int dayInPeriod}) {
  final best = <int, SnapshotPoint>{};
  for (final s in snapshots) {
    if (s.point <= 0) continue;
    final cur = best[s.periodStart];
    if (cur == null || _nearer(s, cur, dayInPeriod)) best[s.periodStart] = s;
  }
  final months = best.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final m in months.take(forecastMaxMonths))
      (best[m]!.actual - best[m]!.point) / best[m]!.point,
  ];
}

bool _nearer(SnapshotPoint a, SnapshotPoint b, int day) {
  final da = (a.dayInPeriod - day).abs();
  final db = (b.dayInPeriod - day).abs();
  return da < db || (da == db && a.dayInPeriod < b.dayInPeriod);
}
