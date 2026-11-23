import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/spending.dart';
import '../home/home_providers.dart';

// Written by hand: these name drift's generated row classes (see add_providers.dart).

/// Every entry in the month before this one, for a budget's carry-over.
final previousMonthRowsProvider = StreamProvider<List<Transaction>>((ref) {
  final calc = ref.watch(periodCalculatorProvider);
  final month = ref.watch(currentMonthProvider);
  return ref.watch(transactionRepositoryProvider).watchIn(calc.previous(month));
});

/// Effective budget against money out this month, for each visible budgeted category: the
/// same lines Budgets draws, before it sorts them. Null until the month, last month and the
/// categories have all loaded.
final budgetLinesProvider = Provider<List<({Category category, int budget, int spent})>?>((ref) {
  final rows = ref.watch(monthRowsProvider).value;
  final previous = ref.watch(previousMonthRowsProvider).value;
  final cats = ref.watch(allCategoriesProvider).value;
  if (rows == null || previous == null || cats == null) return null;
  final calc = ref.watch(periodCalculatorProvider);
  final previousStart = calc.previous(ref.watch(currentMonthProvider)).startDay;
  final spentNow = moneyOutByCategory(rows);
  final spentBefore = moneyOutByCategory(previous);
  return [
    for (final cat in cats)
      if (!cat.isSystem && !cat.hidden && (cat.monthlyBudget ?? 0) > 0)
        (
          category: cat,
          spent: spentNow[cat.id] ?? 0,
          budget: effectiveBudget(
            base: cat.monthlyBudget!,
            carriesOver:
                cat.budgetCarriesOver &&
                carryApplies(budgetSince: cat.budgetSince, previousMonthStartDay: previousStart),
            previousSpent: spentBefore[cat.id] ?? 0,
          ),
        ),
  ];
});

/// What is left across every budget this month, net. Null while loading or with no budget set,
/// so Home can leave its tile out rather than show "0".
final budgetTotalsProvider = Provider<BudgetTotals?>((ref) {
  final lines = ref.watch(budgetLinesProvider);
  if (lines == null || lines.isEmpty) return null;
  return budgetTotalsOf([for (final l in lines) (budget: l.budget, spent: l.spent)]);
});

/// Every entry in the six months before this one, for the history bars and the suggestion.
final budgetHistoryRowsProvider = StreamProvider<List<Transaction>>((ref) {
  final calc = ref.watch(periodCalculatorProvider);
  final month = ref.watch(currentMonthProvider);
  final months = previousMonths(calc, month);
  return ref
      .watch(transactionRepositoryProvider)
      .watchIn(Period(months.first.start, month.start, PeriodKind.custom));
});
