import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/transaction_filter.dart';
import 'date_choice_providers.dart';

/// The Filters choices. Held in memory, like the date choice, and reset by Clear all.
class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void toggleCategory(String id) {
    final next = {...state.categoryIds};
    if (!next.remove(id)) next.add(id);
    state = _with(categoryIds: next);
  }

  /// Drops a category from the choice, for one that was deleted: its chip is gone, so it
  /// could not be unselected, and no entry can match it any more.
  void removeCategory(String id) {
    if (!state.categoryIds.contains(id)) return;
    state = _with(categoryIds: {...state.categoryIds}..remove(id));
  }

  void toggleAccount(String id) {
    final next = {...state.accountIds};
    if (!next.remove(id)) next.add(id);
    state = _with(accountIds: next);
  }

  /// Limits by amount, whole shillings, inclusive. Null on a side means no limit there.
  void setAmounts({int? min, int? max}) {
    if (min != null && max != null && min > max) {
      throw ArgumentError('The lowest amount is above the highest: $min > $max');
    }
    state = _with(minAmount: min, maxAmount: max);
  }

  void setOnlyFee({required bool on}) => state = _with(onlyFee: on);

  void setOnlyUnusual({required bool on}) => state = _with(onlyUnusual: on);

  void setOrder(FilterOrder order) => state = state.withOrder(order);

  /// The search words from the list. Kept when Clear all runs, as they belong to the list.
  void setQuery(String query) => state = _with(query: query);

  /// The direction from the list's All / Money out / Money in choice.
  void setKind(TransactionKind kind) => state = _with(kind: kind);

  /// Clears every choice: the Filters choices, the order, and the date choice.
  void clearAll() {
    final query = state.query;
    final kind = state.kind;
    state = TransactionFilter(query: query, kind: kind);
    ref.read(dateChoiceProvider.notifier).clear();
  }

  TransactionFilter _with({
    Set<String>? categoryIds,
    Set<String>? accountIds,
    Object? minAmount = _keep,
    Object? maxAmount = _keep,
    bool? onlyFee,
    bool? onlyUnusual,
    String? query,
    TransactionKind? kind,
  }) => TransactionFilter(
    categoryIds: categoryIds ?? state.categoryIds,
    accountIds: accountIds ?? state.accountIds,
    minAmount: identical(minAmount, _keep) ? state.minAmount : minAmount as int?,
    maxAmount: identical(maxAmount, _keep) ? state.maxAmount : maxAmount as int?,
    onlyFee: onlyFee ?? state.onlyFee,
    onlyUnusual: onlyUnusual ?? state.onlyUnusual,
    order: state.order,
    query: query ?? state.query,
    kind: kind ?? state.kind,
  );
}

const Object _keep = Object();

final transactionFilterProvider = NotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  TransactionFilterNotifier.new,
);
