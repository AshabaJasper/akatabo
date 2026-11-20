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

/// Every account, including switched-off ones, to name and classify past entries.
final allAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

/// The accounts the person can pay from or move money between.
final enabledAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchEnabled(),
);

/// The account Add opens on, from the accounts it offers: the one marked "Pick this first
/// when I add", or the first account when that one is switched off or none is marked.
/// General and New account name the same account, so all three always agree.
Account? firstPickAccount(List<Account> enabled) {
  for (final a in enabled) {
    if (a.isDefault) return a;
  }
  return enabled.isEmpty ? null : enabled.first;
}
