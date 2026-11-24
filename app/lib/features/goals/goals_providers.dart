import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// Written by hand: these name drift's generated row classes (see budgets_providers.dart).

/// Every goal, archived or not, in the order they were set.
final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).watchAll(),
);

/// One goal by id. Null once it is gone.
final goalProvider = StreamProvider.family<Goal?, String>(
  (ref, id) => ref.watch(goalRepositoryProvider).watchById(id),
);

/// Moves for one goal, newest first.
final goalMovesProvider = StreamProvider.family<List<GoalMove>, String>(
  (ref, id) => ref.watch(goalRepositoryProvider).watchMoves(id),
);

/// Every move in every goal, for the set-aside totals.
final allGoalMovesProvider = StreamProvider<List<GoalMove>>(
  (ref) => ref.watch(goalRepositoryProvider).watchAllMoves(),
);
