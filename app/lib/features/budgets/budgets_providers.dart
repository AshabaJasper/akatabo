import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../home/home_providers.dart';

// Written by hand: these name drift's generated row classes (see add_providers.dart).

/// Every entry in the month before this one, for a budget's carry-over.
final previousMonthRowsProvider = StreamProvider<List<Transaction>>((ref) {
  final calc = ref.watch(periodCalculatorProvider);
  final month = ref.watch(currentMonthProvider);
  return ref.watch(transactionRepositoryProvider).watchIn(calc.previous(month));
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
