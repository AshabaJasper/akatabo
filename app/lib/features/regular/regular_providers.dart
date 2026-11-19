import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';

// Written by hand: these name drift's generated row class (see add_providers.dart).

final regularPaymentRepositoryProvider = Provider<RegularPaymentRepository>(
  (ref) => RegularPaymentRepository(ref.watch(appDatabaseProvider)),
);

/// The payments the person has not dismissed, soonest first.
final activeRegularProvider = StreamProvider.autoDispose<List<RegularPayment>>(
  (ref) => ref.watch(regularPaymentRepositoryProvider).watchActive(),
);
