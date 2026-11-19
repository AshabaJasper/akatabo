import '../data/db/app_database.dart';
import '../data/seed/default_data.dart';

/// The money rules from DESIGN_SYSTEM.md, "Rules for the numbers", written once.
///
/// Pure Dart: no Flutter, no database queries. Screens call these with rows they have
/// already read, so every figure on a screen comes from one place.

/// What one transaction takes out of the person's accounts.
///
/// Money out is the amount plus its fee and tax. A transfer moves money between the
/// person's own accounts, so only its fee and tax count as money out (owner decision 1).
/// Money in takes nothing out.
int moneyOutOf(Transaction t) => switch (t.direction) {
  Direction.moneyOut => t.amount + t.fee + t.tax,
  Direction.transfer => t.fee + t.tax,
  Direction.moneyIn => 0,
};

/// "Total cost to you" on one transaction: amount plus fee plus tax, whatever the direction.
int totalCostOf(Transaction t) => t.amount + t.fee + t.tax;

/// Money that came in. A transfer is not income, so it is never counted here.
int moneyInOf(Transaction t) => t.direction == Direction.moneyIn ? t.amount : 0;

/// The totals for a set of transactions over one period.
class PeriodTotals {
  const PeriodTotals({required this.moneyOut, required this.moneyIn});

  /// Money out, including fees and tax.
  final int moneyOut;
  final int moneyIn;

  /// Money in minus money out. Negative when the person spent more than came in.
  int get net => moneyIn - moneyOut;

  static const empty = PeriodTotals(moneyOut: 0, moneyIn: 0);
}

PeriodTotals totalsOf(Iterable<Transaction> rows) {
  var out = 0;
  var inward = 0;
  for (final t in rows) {
    out += moneyOutOf(t);
    inward += moneyInOf(t);
  }
  return PeriodTotals(moneyOut: out, moneyIn: inward);
}

/// Money out split by category, so the parts add back to [totalsOf] `.moneyOut`.
///
/// An entry's amount goes to its own category. Its fee and tax go to the reserved
/// "Fees and tax" category. Nothing is counted twice, so the shares add to 100%.
/// Income is not part of this split.
Map<String, int> moneyOutByCategory(Iterable<Transaction> rows) {
  final parts = <String, int>{};
  void add(String id, int amount) {
    if (amount == 0) return;
    parts.update(id, (v) => v + amount, ifAbsent: () => amount);
  }

  for (final t in rows) {
    if (t.direction == Direction.moneyIn) continue;
    if (t.direction == Direction.moneyOut) {
      add(t.categoryId ?? DefaultIds.other, t.amount);
    }
    add(DefaultIds.fees, t.fee + t.tax);
  }
  return parts;
}

/// The money-out total for the first [days] days of a period, used for "same days" comparisons.
///
/// [rows] must already be limited to the period being compared.
int moneyOutOnDays(Iterable<Transaction> rows, {required int startDay, required int days}) {
  final endDay = startDay + days;
  return totalsOf(rows.where((t) => t.localDay >= startDay && t.localDay < endDay)).moneyOut;
}

/// The change between this period and the previous one, in whole percent, or null when the
/// previous figure is zero (there is nothing to compare with).
int? percentChange({required int current, required int previous}) {
  if (previous == 0) return null;
  return ((current - previous) * 100 / previous).round();
}
