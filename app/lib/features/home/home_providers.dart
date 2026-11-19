import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// Written by hand: these name drift's generated row classes (see add_providers.dart).

/// The current month, from "Month starts on".
final currentMonthProvider = Provider<Period>(
  (ref) => ref.watch(periodCalculatorProvider).month(ref.watch(appNowProvider)),
);

/// The same number of days at the start of last month, for "above this point in October".
final previousSameDaysProvider = Provider<Period>((ref) {
  final calc = ref.watch(periodCalculatorProvider);
  final now = ref.watch(appNowProvider);
  return calc.sameDaysOfPrevious(calc.month(now), now);
});

/// Every entry in the current month.
final monthRowsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchIn(ref.watch(currentMonthProvider)),
);

/// Entries over the same days last month.
final previousSameDaysRowsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchIn(ref.watch(previousSameDaysProvider)),
);

/// The newest three entries. An empty list means there are no entries at all.
final latestRowsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchLatest(3),
);

/// Every category, including the reserved fees one, to name the rows of a split.
final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);
