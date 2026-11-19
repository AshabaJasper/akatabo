import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// Written by hand: it names drift's generated row class (see add_providers.dart).

/// Every entry in one period, for Insights. Closes its database watch when the period changes.
final insightsRowsProvider = StreamProvider.autoDispose.family<List<Transaction>, Period>(
  (ref, period) => ref.watch(transactionRepositoryProvider).watchIn(period),
);
