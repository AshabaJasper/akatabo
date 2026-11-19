import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

// Written by hand rather than with the generator: these return drift's generated row
// classes, which the generator cannot resolve while it runs in the same build.

/// The categories a person can pick for money out. The reserved "Fees and tax" category is
/// filled from the fee and tax fields, so it is never offered here.
final spendingCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref
      .watch(categoryRepositoryProvider)
      .watch(CategoryKind.spending)
      .map((rows) => rows.where((c) => !c.isSystem).toList()),
);

/// The categories for money in.
final incomeCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watch(CategoryKind.income),
);

/// The accounts the person can pay from or move money between.
final enabledAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchEnabled(),
);
