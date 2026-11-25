import '../core/time/period.dart';
import '../data/db/app_database.dart';
import 'goals.dart';
import 'spending.dart';

/// What happened in one Calendar period: money out and in, the change against the same days
/// of the period before, the biggest categories, and what was set aside for goals.
class PeriodSummary {
  const PeriodSummary({
    required this.moneyOut,
    required this.moneyIn,
    required this.previousOut,
    required this.topCategories,
    required this.setAside,
  });

  final int moneyOut;
  final int moneyIn;

  /// Money out in the same days of the period before (the whole of it once this one ends).
  final int previousOut;

  /// Up to three categories by money out, largest first. Fees and tax count as one.
  final List<MapEntry<String, int>> topCategories;

  /// Goal money set aside in the period, less what was taken back out. Can be negative.
  final int setAside;

  /// In less out. Positive means more came in than went out.
  int get net => moneyIn - moneyOut;

  /// Whole percent against [previousOut], or null when there is nothing to compare with.
  int? get change => percentChange(current: moneyOut, previous: previousOut);

  /// Nothing went in or out. Goal moves do not count: they leave balances as they are.
  bool get isEmpty => moneyOut == 0 && moneyIn == 0;
}

/// Sums [rows] (entries in [period]) against [previousRows] (the same days before), and the
/// [goalMoves] that fall inside [period]. Moves outside it are ignored, so callers can pass
/// every move.
PeriodSummary summarisePeriod({
  required Period period,
  required Iterable<Transaction> rows,
  required Iterable<Transaction> previousRows,
  required Iterable<GoalMoveEntry> goalMoves,
}) {
  final totals = totalsOf(rows);
  final byCategory = moneyOutByCategory(rows).entries.where((e) => e.value > 0).toList()
    // Largest first; a tie goes by id, so the order never shifts between redraws.
    ..sort((a, b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
    });
  final inPeriod = goalMoves.where(
    (m) => m.localDay >= period.startDay && m.localDay < period.endDay,
  );
  return PeriodSummary(
    moneyOut: totals.moneyOut,
    moneyIn: totals.moneyIn,
    previousOut: totalsOf(previousRows).moneyOut,
    topCategories: byCategory.take(3).toList(),
    setAside: savedOf(inPeriod),
  );
}
