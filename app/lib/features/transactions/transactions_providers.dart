import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// Written by hand: these name drift's generated row classes (see add_providers.dart).
// Auto-dispose: each opens a database watch that should close when its screen does.

/// Every transaction, newest first.
final allTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

/// One transaction by id; null once it has been deleted.
final transactionByIdProvider = StreamProvider.autoDispose.family<Transaction?, String>(
  (ref, id) => ref.watch(transactionRepositoryProvider).watchById(id),
);
