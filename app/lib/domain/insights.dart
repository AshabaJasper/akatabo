import '../core/time/period.dart';
import '../data/db/app_database.dart';
import 'calendar.dart';
import 'spending.dart';

/// One category's money out in this period and the same days last time.
class CategoryChange {
  const CategoryChange({required this.categoryId, required this.current, required this.previous});

  final String categoryId;
  final int current;
  final int previous;

  int get change => current - previous;

  /// The change in whole percent, or null when there was nothing to compare with.
  int? get percent => percentChange(current: current, previous: previous);
}

/// Every category's change between two sets of entries, the biggest change first.
List<CategoryChange> categoryChanges({
  required Iterable<Transaction> current,
  required Iterable<Transaction> previous,
}) {
  final now = moneyOutByCategory(current);
  final before = moneyOutByCategory(previous);
  final ids = {...now.keys, ...before.keys};
  final changes = [
    for (final id in ids)
      CategoryChange(categoryId: id, current: now[id] ?? 0, previous: before[id] ?? 0),
  ];
  changes.sort((a, b) => b.change.abs().compareTo(a.change.abs()));
  return changes;
}

/// Money out, running from the first day of [start] over [days] days.
///
/// Each entry is the total so far. A day after [until] has no figure yet and is null, so a
/// chart stops at today instead of drawing a flat line into the future.
List<double?> runningTotal(
  Iterable<Transaction> rows,
  DateTime start,
  int days, {
  DateTime? until,
}) {
  final byDay = moneyOutByDay(rows);
  final totals = <double?>[];
  var run = 0;
  for (var i = 0; i < days; i++) {
    final day = addDays(start, i);
    run += byDay[toLocalDay(day)] ?? 0;
    final notYet = until != null && day.isAfter(until);
    totals.add(notYet ? null : run.toDouble());
  }
  return totals;
}
