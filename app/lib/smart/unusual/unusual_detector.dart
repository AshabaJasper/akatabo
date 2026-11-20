/// Unusual payment score: the Dart port of ml/unusual/score.py. No Flutter imports.
///
/// A transparent sum of three signals, each of which the app can say in plain words:
///
/// - amount: how far the amount sits above the person's usual amount, as a robust z score on
///   log amounts, `(ln x - median) / (madScale * max(MAD, madFloor))`, upward only. The usual
///   amount is this payee's own history when there are at least [UnusualParams.minPayeeHistory]
///   earlier payments to it, otherwise the category's history.
/// - hour: [UnusualParams.hourWeight] when fewer than [UnusualParams.hourShareMin] of the
///   person's earlier entries were made at this hour.
/// - payee: [UnusualParams.payeeWeight] when no earlier payee key is equal or one edit away.
///
/// An entry is flagged when its category has at least [UnusualParams.minCategoryHistory]
/// earlier entries and the score reaches the threshold for the person's setting.
library;

import 'dart:math' as math;

import '../regular/stats.dart';

/// "How often" on Smart help. Kept here, not taken from the settings layer, so this file
/// needs nothing outside `smart/`.
enum UnusualLevel { rarely, balanced, often }

/// Why an entry stands out. The screen turns each into a sentence.
enum UnusualReason { amount, hour, payee }

/// One money-out entry as the detector sees it. [day] is a day number (days since an
/// epoch); it is carried for callers and not used in the score.
class UnusualEntry {
  const UnusualEntry({
    required this.amount,
    required this.categoryId,
    required this.hour,
    required this.payeeKey,
    required this.day,
  });

  factory UnusualEntry.fromJson(Map<String, Object?> j) => UnusualEntry(
    amount: j['amount']! as int,
    categoryId: j['categoryId']! as String,
    hour: j['hour']! as int,
    payeeKey: j['payeeKey']! as String,
    day: j['day']! as int,
  );

  final int amount;
  final String categoryId;
  final int hour;
  final String payeeKey;
  final int day;
}

/// The constants and thresholds from assets/smart/unusual_params.json.
class UnusualParams {
  const UnusualParams({
    required this.minCategoryHistory,
    required this.minPayeeHistory,
    required this.madScale,
    required this.madFloor,
    required this.amountReasonZ,
    required this.hourShareMin,
    required this.hourWeight,
    required this.payeeWeight,
    required this.thresholds,
  });

  factory UnusualParams.fromJson(Map<String, Object?> j) {
    final t = (j['thresholds']! as Map).cast<String, Object?>();
    return UnusualParams(
      minCategoryHistory: j['minCategoryHistory']! as int,
      minPayeeHistory: j['minPayeeHistory']! as int,
      madScale: (j['madScale']! as num).toDouble(),
      madFloor: (j['madFloor']! as num).toDouble(),
      amountReasonZ: (j['amountReasonZ']! as num).toDouble(),
      hourShareMin: (j['hourShareMin']! as num).toDouble(),
      hourWeight: (j['hourWeight']! as num).toDouble(),
      payeeWeight: (j['payeeWeight']! as num).toDouble(),
      thresholds: {for (final l in UnusualLevel.values) l: (t[l.name]! as num).toDouble()},
    );
  }

  final int minCategoryHistory;
  final int minPayeeHistory;
  final double madScale;
  final double madFloor;
  final double amountReasonZ;
  final double hourShareMin;
  final double hourWeight;
  final double payeeWeight;
  final Map<UnusualLevel, double> thresholds;
}

/// Where the usual amount came from.
enum UnusualBasis { payee, category, none }

/// The parts of the score before weights and the threshold are applied.
class UnusualSignals {
  const UnusualSignals({
    required this.gatePassed,
    required this.amountZ,
    required this.usualAmount,
    required this.basis,
    required this.hourShare,
    required this.newPayee,
  });

  final bool gatePassed;

  /// Upward robust z; 0 when there is nothing to compare with.
  final double amountZ;

  /// exp(median log amount) of the baseline; 0 when there is none.
  final double usualAmount;
  final UnusualBasis basis;

  /// Share of earlier entries made at this hour; 1 when there are none.
  final double hourShare;
  final bool newPayee;
}

class UnusualResult {
  const UnusualResult({
    required this.score,
    required this.flagged,
    required this.reasons,
    required this.signals,
  });

  final double score;
  final bool flagged;
  final List<UnusualReason> reasons;
  final UnusualSignals signals;
}

/// Optimal string alignment distance: insertions, deletions, substitutions and swaps of two
/// neighbouring characters each cost 1.
int osaDistance(String a, String b) {
  final n = a.length;
  final m = b.length;
  var prev2 = List<int>.filled(m + 1, 0);
  var prev = List<int>.generate(m + 1, (j) => j);
  for (var i = 1; i <= n; i++) {
    final cur = List<int>.filled(m + 1, 0)..[0] = i;
    for (var j = 1; j <= m; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = math.min(math.min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        best = math.min(best, prev2[j - 2] + 1);
      }
      cur[j] = best;
    }
    prev2 = prev;
    prev = cur;
  }
  return prev[m];
}

/// True when no earlier key is equal to [key] or one edit away. An empty key is never new.
bool isNewPayee(String key, Set<String> earlierKeys) {
  if (key.isEmpty || earlierKeys.contains(key)) return false;
  for (final k in earlierKeys) {
    if (k.isNotEmpty && (k.length - key.length).abs() <= 1 && osaDistance(key, k) <= 1) {
      return false;
    }
  }
  return true;
}

UnusualSignals unusualSignals(UnusualEntry entry, List<UnusualEntry> history, UnusualParams p) {
  final category = [
    for (final h in history)
      if (h.categoryId == entry.categoryId) h,
  ];
  final gate = category.length >= p.minCategoryHistory;

  final samePayee = entry.payeeKey.isEmpty
      ? const <UnusualEntry>[]
      : [
          for (final h in history)
            if (h.payeeKey == entry.payeeKey) h,
        ];
  var baseline = category;
  var basis = UnusualBasis.category;
  if (samePayee.length >= p.minPayeeHistory) {
    baseline = samePayee;
    basis = UnusualBasis.payee;
  }
  final logs = [
    for (final h in baseline)
      if (h.amount > 0) math.log(h.amount),
  ];
  var amountZ = 0.0;
  var usual = 0.0;
  if (entry.amount <= 0 || logs.isEmpty) {
    basis = UnusualBasis.none;
  } else {
    final centre = medianOf(logs);
    final mad = medianOf([for (final v in logs) (v - centre).abs()]);
    final scale = p.madScale * math.max(mad, p.madFloor);
    final z = (math.log(entry.amount) - centre) / scale;
    amountZ = z > 0 ? z : 0.0;
    usual = math.exp(centre);
  }

  var hourShare = 1.0;
  if (history.isNotEmpty) {
    var atHour = 0;
    for (final h in history) {
      if (h.hour == entry.hour) atHour++;
    }
    hourShare = atHour / history.length;
  }

  final newPayee = isNewPayee(entry.payeeKey, {for (final h in history) h.payeeKey});
  return UnusualSignals(
    gatePassed: gate,
    amountZ: amountZ,
    usualAmount: usual,
    basis: basis,
    hourShare: hourShare,
    newPayee: newPayee,
  );
}

UnusualResult combineUnusual(UnusualSignals s, UnusualParams p, UnusualLevel level) {
  final hour = s.hourShare < p.hourShareMin ? p.hourWeight : 0.0;
  final payee = s.newPayee ? p.payeeWeight : 0.0;
  final score = s.amountZ + hour + payee;
  return UnusualResult(
    score: score,
    flagged: s.gatePassed && score >= p.thresholds[level]!,
    reasons: [
      if (s.amountZ >= p.amountReasonZ) UnusualReason.amount,
      if (hour > 0) UnusualReason.hour,
      if (payee > 0) UnusualReason.payee,
    ],
    signals: s,
  );
}

/// Scores [entry] against the [history] of entries made before it.
UnusualResult scoreUnusual(
  UnusualEntry entry,
  List<UnusualEntry> history,
  UnusualParams p, {
  UnusualLevel level = UnusualLevel.balanced,
}) => combineUnusual(unusualSignals(entry, history, p), p, level);
