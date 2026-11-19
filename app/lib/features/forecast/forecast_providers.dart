import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/forecast.dart';

// Written by hand: it names drift's generated row class (see add_providers.dart).

/// Every entry in the rate window, which is the last [rateWindowDays] days up to today.
/// Closes its watch when the day changes, so the window moves on at midnight.
final forecastWindowRowsProvider = StreamProvider.autoDispose<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchIn(rateWindow(ref.watch(appNowProvider))),
);
