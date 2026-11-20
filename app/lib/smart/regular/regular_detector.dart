/// Regular payment detection: the Dart port of ml/regular/detect.py. No Flutter imports.
///
/// One payee key at a time (empty keys are skipped):
///
/// 1. at least [RegularParams.minOccurrences] payments;
/// 2. a median gap of at least [RegularParams.minIntervalDays] (so lunch bought most days is
///    never called a bill) and at most [RegularParams.maxIntervalDays];
/// 3. regular gaps: each gap is divided by the whole intervals it spans, so one missed month
///    counts as two gaps of a month; the coefficient of variation of those unit gaps is at
///    most [RegularParams.cvMax], and missed intervals are at most
///    [RegularParams.maxMissedShare] of all intervals;
/// 4. at least [RegularParams.amountShareMin] of the amounts within [RegularParams.amountBand]
///    of the median amount;
/// 5. still current: the last payment no more than [RegularParams.staleIntervals] intervals
///    before today.
///
/// Prediction: next day = last day + the median unit gap, rounded; the amount range is the
/// lowest and highest amount inside the band.
library;

import 'dart:math' as math;

import 'stats.dart';

/// One money-out payment. [day] is a day number (days since an epoch).
class PaidEntry {
  const PaidEntry({
    required this.amount,
    required this.categoryId,
    required this.payeeKey,
    required this.day,
  });

  factory PaidEntry.fromJson(Map<String, Object?> j) => PaidEntry(
    amount: j['amount']! as int,
    categoryId: j['categoryId']! as String,
    payeeKey: j['payeeKey']! as String,
    day: j['day']! as int,
  );

  final int amount;
  final String categoryId;
  final String payeeKey;
  final int day;
}

/// The rule's constants from assets/smart/regular_params.json.
class RegularParams {
  const RegularParams({
    required this.minOccurrences,
    required this.minIntervalDays,
    required this.maxIntervalDays,
    required this.cvMax,
    required this.amountBand,
    required this.amountShareMin,
    required this.staleIntervals,
    required this.maxMissedShare,
  });

  factory RegularParams.fromJson(Map<String, Object?> j) => RegularParams(
    minOccurrences: j['minOccurrences']! as int,
    minIntervalDays: (j['minIntervalDays']! as num).toDouble(),
    maxIntervalDays: (j['maxIntervalDays']! as num).toDouble(),
    cvMax: (j['cvMax']! as num).toDouble(),
    amountBand: (j['amountBand']! as num).toDouble(),
    amountShareMin: (j['amountShareMin']! as num).toDouble(),
    staleIntervals: (j['staleIntervals']! as num).toDouble(),
    maxMissedShare: (j['maxMissedShare']! as num).toDouble(),
  );

  final int minOccurrences;
  final double minIntervalDays;
  final double maxIntervalDays;
  final double cvMax;
  final double amountBand;
  final double amountShareMin;
  final double staleIntervals;
  final double maxMissedShare;
}

class RegularSeries {
  const RegularSeries({
    required this.payeeKey,
    required this.categoryId,
    required this.occurrences,
    required this.interval,
    required this.intervalDays,
    required this.gapCv,
    required this.typicalAmount,
    required this.amountLow,
    required this.amountHigh,
    required this.lastDay,
    required this.nextDay,
    required this.nextDueFromToday,
  });

  final String payeeKey;

  /// The category most of the payments used; the first by id on a tie.
  final String categoryId;
  final int occurrences;
  final double interval;
  final int intervalDays;
  final double gapCv;
  final int typicalAmount;
  final int amountLow;
  final int amountHigh;
  final int lastDay;

  /// Last day plus the interval: the prediction that is evaluated.
  final int nextDay;

  /// The first predicted day on or after today, for showing and saving.
  final int nextDueFromToday;
}

String _category(List<PaidEntry> group) {
  final counts = <String, int>{};
  for (final g in group) {
    counts[g.categoryId] = (counts[g.categoryId] ?? 0) + 1;
  }
  final best = counts.values.reduce(math.max);
  final tied = [
    for (final e in counts.entries)
      if (e.value == best) e.key,
  ]..sort();
  return tied.first;
}

/// The series for one payee's payments, or null when the rule rejects it.
RegularSeries? checkRegular(List<PaidEntry> payments, int today, RegularParams p) {
  final group = [...payments]
    ..sort((a, b) {
      final d = a.day.compareTo(b.day);
      return d != 0 ? d : a.amount.compareTo(b.amount);
    });
  final n = group.length;
  if (n < p.minOccurrences) return null;
  final days = [for (final g in group) g.day];
  final gaps = [for (var i = 0; i < n - 1; i++) (days[i + 1] - days[i]).toDouble()];
  final medGap = medianOf(gaps);
  if (medGap < p.minIntervalDays || medGap > p.maxIntervalDays) return null;
  final spans = [for (final g in gaps) math.max(1, roundHalfUp(g / medGap))];
  final spanSum = spans.fold<int>(0, (a, b) => a + b);
  if (spanSum - spans.length > p.maxMissedShare * spanSum) return null;
  final units = [for (var i = 0; i < gaps.length; i++) gaps[i] / spans[i]];
  final mean = plainSum(units) / units.length;
  final variance = plainSum([for (final u in units) (u - mean) * (u - mean)]) / units.length;
  final cv = mean > 0 ? math.sqrt(variance) / mean : double.infinity;
  if (cv > p.cvMax) return null;

  final amounts = [for (final g in group) g.amount.toDouble()];
  final medAmount = medianOf(amounts);
  final band = [
    for (final a in amounts)
      if ((a - medAmount).abs() <= p.amountBand * medAmount) a,
  ];
  if (band.length < p.amountShareMin * n) return null;

  final interval = medianOf(units);
  final intervalDays = math.max(1, roundHalfUp(interval));
  final last = days.last;
  if (today - last > p.staleIntervals * interval) return null;
  final nextDay = last + intervalDays;
  var nextDue = nextDay;
  if (nextDue < today) {
    nextDue += ((today - nextDue + intervalDays - 1) ~/ intervalDays) * intervalDays;
  }
  return RegularSeries(
    payeeKey: group.first.payeeKey,
    categoryId: _category(group),
    occurrences: n,
    interval: interval,
    intervalDays: intervalDays,
    gapCv: cv,
    typicalAmount: roundHalfUp(medianOf(band)),
    amountLow: band.reduce(math.min).toInt(),
    amountHigh: band.reduce(math.max).toInt(),
    lastDay: last,
    nextDay: nextDay,
    nextDueFromToday: nextDue,
  );
}

/// Every regular series in [payments] as of [today], sorted by payee key.
List<RegularSeries> detectRegular(List<PaidEntry> payments, int today, RegularParams p) {
  final groups = <String, List<PaidEntry>>{};
  for (final pay in payments) {
    if (pay.payeeKey.isNotEmpty) (groups[pay.payeeKey] ??= []).add(pay);
  }
  final keys = groups.keys.toList()..sort();
  return [for (final k in keys) ?checkRegular(groups[k]!, today, p)];
}
