import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../domain/income.dart';
import '../home/home_providers.dart';

/// The days the Money-in categories page counts: from the start of the month ("Month starts
/// on") through today. Entries dated later this month are not counted yet, so the figures
/// match the "1 to 19 November" line above them.
final incomeDaysProvider = Provider.autoDispose<Period>((ref) {
  final month = ref.watch(currentMonthProvider);
  final today = dateOnly(ref.watch(appNowProvider));
  return Period(month.start, addDays(today, 1), PeriodKind.custom);
});

/// Money in by income category over [incomeDaysProvider]: loading, an error, or the summary.
final incomeSummaryProvider = Provider.autoDispose<AsyncValue<IncomeSummary>>((ref) {
  final cats = ref.watch(allCategoriesProvider);
  final rows = ref.watch(monthRowsProvider);
  if (cats.hasError) return AsyncValue.error(cats.error!, cats.stackTrace ?? StackTrace.empty);
  if (rows.hasError) return AsyncValue.error(rows.error!, rows.stackTrace ?? StackTrace.empty);
  if (!cats.hasValue || !rows.hasValue) return const AsyncValue.loading();
  final days = ref.watch(incomeDaysProvider);
  final inDays = rows.requireValue.where((t) => days.containsDay(t.localDay));
  return AsyncValue.data(incomeByCategory(cats.requireValue, inDays));
});
