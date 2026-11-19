import '../core/time/period.dart';
import '../data/db/app_database.dart';
import '../data/seed/default_data.dart';

/// Budgets: how a category's spending stands against its monthly budget.
///
/// Pure Dart. Every comparison is in whole shillings and whole percents, so a boundary such as
/// "exactly 80% used" or "exactly on pace" is decided by integer arithmetic, never by a
/// rounded double.

/// Where a budget stands, in the order the screens check it: the first one that applies wins.
enum BudgetStatus {
  /// Spent more than the budget.
  over,

  /// Spent at or past the person's warn level (80% by default), but not over.
  nearlyUsed,

  /// Spent more than the share of the month that has passed.
  aLittleAhead,

  /// None of the above.
  onTrack,
}

/// Fewest months of history before a suggested budget is offered.
const suggestionMinMonths = 3;

/// Months of history a suggestion is worked out from.
const suggestionMonths = 6;

/// The status of a budget of [budget] shillings with [spent] spent, [warnAt] percent as the
/// warn level, on day [day] of a month of [daysInMonth] days.
///
/// Over: spent > budget. Nearly used: spent × 100 ≥ budget × warnAt. A little ahead:
/// spent ÷ budget > day ÷ daysInMonth (strictly, so exactly on pace is on track).
BudgetStatus budgetStatus({
  required int spent,
  required int budget,
  required int warnAt,
  required int day,
  required int daysInMonth,
}) {
  if (budget <= 0) throw ArgumentError.value(budget, 'budget', 'must be above zero');
  if (spent > budget) return BudgetStatus.over;
  if (spent * 100 >= budget * warnAt) return BudgetStatus.nearlyUsed;
  if (spent * daysInMonth > budget * day) return BudgetStatus.aLittleAhead;
  return BudgetStatus.onTrack;
}

/// The share of the month that has passed, from 0 to 1: day ÷ days in the month. The budget
/// bar's tick sits here.
double budgetPace({required int day, required int daysInMonth}) =>
    daysInMonth <= 0 ? 0 : (day / daysInMonth).clamp(0, 1).toDouble();

/// How much a person can spend each day for the rest of the month, rounded down to the
/// hundred so the figure is easy to say. Zero once the budget is spent. With no days left
/// (the last day), it is what remains.
int allowancePerDay({required int budget, required int spent, required int daysLeft}) {
  final remaining = budget - spent;
  if (remaining <= 0) return 0;
  if (daysLeft <= 0) return remaining;
  return remaining ~/ daysLeft ~/ 100 * 100;
}

/// The overall figure across every budget: what is left, net, so one category's overspend
/// comes off the others' savings.
class BudgetTotals {
  const BudgetTotals({required this.budget, required this.spent});

  /// The sum of the budgets.
  final int budget;

  /// The sum of what was spent in the budgeted categories.
  final int spent;

  /// Budget less spent. Negative when the month is over budget overall.
  int get left => budget - spent;
}

/// Sums budgets and spending over the budgeted categories only.
BudgetTotals budgetTotalsOf(Iterable<({int budget, int spent})> lines) {
  var budget = 0;
  var spent = 0;
  for (final l in lines) {
    budget += l.budget;
    spent += l.spent;
  }
  return BudgetTotals(budget: budget, spent: spent);
}

/// What a budget carries into the next month: the unspent part of this month's budget, and
/// nothing when it was overspent. It carries one month forward and does not compound: the
/// next month's carry is worked out from its own base budget only.
int carryIntoNextMonth({required int budget, required int spent}) =>
    budget - spent > 0 ? budget - spent : 0;

/// Whether carry-over applies this month: only once the budget (and its carry-over) covered
/// the whole of last month. [budgetSince] is the local day it started (yyyymmdd); a budget set
/// in the middle of last month, or this month, carries nothing yet.
bool carryApplies({required int? budgetSince, required int previousMonthStartDay}) =>
    budgetSince != null && budgetSince <= previousMonthStartDay;

/// The budget for a month: the base, plus what carries over from last month when it is on.
int effectiveBudget({required int base, required bool carriesOver, required int previousSpent}) =>
    carriesOver ? base + carryIntoNextMonth(budget: base, spent: previousSpent) : base;

/// A suggested monthly budget from a category's past months: the amount that would have
/// covered the most of them. It is the value the fifth of six months (the 80th percentile)
/// reaches, rounded up to the next 10,000 so the figure is easy to say. Null until
/// [suggestionMinMonths] months of history exist.
///
/// [monthlyTotals] are the money out per month, oldest first, zero for a month with none.
int? suggestedBudget(List<int> monthlyTotals) {
  final months = monthlyTotals.length > suggestionMonths
      ? monthlyTotals.sublist(monthlyTotals.length - suggestionMonths)
      : monthlyTotals;
  if (months.length < suggestionMinMonths) return null;
  final sorted = [...months]..sort();
  final index = (sorted.length * 0.8).ceil() - 1;
  final value = sorted[index];
  return (value + 9999) ~/ 10000 * 10000;
}

/// How many of [monthlyTotals] a budget of [budget] would have covered.
int monthsCovered(List<int> monthlyTotals, int budget) =>
    monthlyTotals.where((m) => m <= budget).length;

/// The [count] periods before [current], oldest first, for the suggestion and the history bars.
List<Period> previousMonths(PeriodCalculator calc, Period current, {int count = suggestionMonths}) {
  final out = <Period>[];
  var p = current;
  for (var i = 0; i < count; i++) {
    p = calc.previous(p);
    out.insert(0, p);
  }
  return out;
}

/// Money out per month for one category, one total for each of [months] (oldest first). Only
/// the amount counts, as the category totals do: fees and tax are in their own category.
List<int> monthlyMoneyOut({
  required String categoryId,
  required List<Period> months,
  required List<Transaction> rows,
}) => [
  for (final m in months)
    rows.fold<int>(
      0,
      (sum, t) =>
          t.direction == Direction.moneyOut &&
              (t.categoryId ?? DefaultIds.other) == categoryId &&
              m.containsDay(t.localDay)
          ? sum + t.amount
          : sum,
    ),
];
