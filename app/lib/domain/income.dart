import '../data/db/app_database.dart';
import 'spending.dart';

/// Money in by category for one period, for the Money-in categories page.
///
/// Pure Dart: no Flutter, no database queries. The amounts use [moneyInOf] and the total uses
/// [totalsOf], so this page and Home count money in the same way.

/// One money-in category and what came in under it.
class IncomeLine {
  const IncomeLine({required this.category, required this.amount, required this.payments});

  final Category category;

  /// Money in under this category, in whole shillings.
  final int amount;

  /// How many money-in entries made up [amount].
  final int payments;
}

class IncomeSummary {
  const IncomeSummary({required this.lines, required this.total});

  /// The money-in categories in the person's order.
  final List<IncomeLine> lines;

  /// All money in over the same rows, as Home counts it.
  final int total;
}

/// Money in per income category over [rows], which the caller has already limited to the
/// period shown.
///
/// [categories] is every category in the person's order. Spending and system categories are
/// left out. A hidden category is listed only when money came in under it, so the rows still
/// add up to [IncomeSummary.total] when an old entry keeps a category hidden since.
IncomeSummary incomeByCategory(Iterable<Category> categories, Iterable<Transaction> rows) {
  final amounts = <String, int>{};
  final counts = <String, int>{};
  for (final t in rows) {
    final id = t.categoryId;
    if (t.direction != Direction.moneyIn || id == null) continue;
    amounts.update(id, (v) => v + moneyInOf(t), ifAbsent: () => moneyInOf(t));
    counts.update(id, (v) => v + 1, ifAbsent: () => 1);
  }
  final lines = [
    for (final c in categories)
      if (c.kind == CategoryKind.income && !c.isSystem && (!c.hidden || (counts[c.id] ?? 0) > 0))
        IncomeLine(category: c, amount: amounts[c.id] ?? 0, payments: counts[c.id] ?? 0),
  ];
  return IncomeSummary(lines: lines, total: totalsOf(rows).moneyIn);
}
