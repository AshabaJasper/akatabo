/// Filters for the All transactions list, and how its rows are ordered. No Flutter imports.
library;

import '../core/time/period.dart';
import '../data/db/app_database.dart';

enum FilterOrder { newest, largest, oldest }

/// Which direction of money the list shows.
enum TransactionKind { all, moneyOut, moneyIn }

/// What the person narrowed the list to. Empty sets, nulls and "all" mean "any".
///
/// The search words and the direction live here too, not only on the list, so the Filters
/// screen's count and the list always agree.
class TransactionFilter {
  const TransactionFilter({
    this.categoryIds = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
    this.onlyFee = false,
    this.onlyUnusual = false,
    this.order = FilterOrder.newest,
    this.query = '',
    this.kind = TransactionKind.all,
  });

  final Set<String> categoryIds;

  /// The accounts money was paid from.
  final Set<String> accountIds;

  /// Whole shillings, inclusive. Null means no limit on that side.
  final int? minAmount;
  final int? maxAmount;

  /// Only entries that carry a fee.
  final bool onlyFee;

  /// Only entries the app flagged as unusual and the person has not dismissed.
  final bool onlyUnusual;

  final FilterOrder order;

  /// Words, or digits for an amount, typed into the search box.
  final String query;

  final TransactionKind kind;

  /// True when a Filters choice narrows the list. Order, search and direction do not count.
  bool get narrows =>
      categoryIds.isNotEmpty ||
      accountIds.isNotEmpty ||
      minAmount != null ||
      maxAmount != null ||
      onlyFee ||
      onlyUnusual;

  /// True when anything at all narrows the list: a Filters choice, the search or the direction.
  bool get anyNarrowing => narrows || query.trim().isNotEmpty || kind != TransactionKind.all;

  /// Only the search box and the direction. The Calendar day view uses this: it has those
  /// controls but no Filters button, so a Filters choice made elsewhere must not hide entries.
  TransactionFilter get listControlsOnly => TransactionFilter(query: query, kind: kind);

  TransactionFilter withOrder(FilterOrder o) => TransactionFilter(
    categoryIds: categoryIds,
    accountIds: accountIds,
    minAmount: minAmount,
    maxAmount: maxAmount,
    onlyFee: onlyFee,
    onlyUnusual: onlyUnusual,
    order: o,
    query: query,
    kind: kind,
  );
}

/// Whether [t] is shown under [f] and the [period] chosen on Choose dates (null for all dates).
///
/// A transfer has no category, so any category choice leaves it out.
bool matchesFilter(Transaction t, TransactionFilter f, Period? period) {
  if (period != null && !period.containsDay(t.localDay)) return false;
  if (!_matchesKind(t, f.kind)) return false;
  if (!_matchesQuery(t, f.query)) return false;
  if (f.categoryIds.isNotEmpty && (t.categoryId == null || !f.categoryIds.contains(t.categoryId))) {
    return false;
  }
  if (f.accountIds.isNotEmpty && !f.accountIds.contains(t.accountId)) return false;
  if (f.minAmount != null && t.amount < f.minAmount!) return false;
  if (f.maxAmount != null && t.amount > f.maxAmount!) return false;
  if (f.onlyFee && t.fee <= 0) return false;
  if (f.onlyUnusual && !(t.flaggedUnusual && !t.flagDismissed)) return false;
  return true;
}

bool _matchesKind(Transaction t, TransactionKind kind) => switch (kind) {
  TransactionKind.all => true,
  TransactionKind.moneyOut => t.direction == Direction.moneyOut,
  TransactionKind.moneyIn => t.direction == Direction.moneyIn,
};

/// Words match the description or the note. Digits also match the amount, so "5000" finds
/// 15,000 and 5,000 alike.
bool _matchesQuery(Transaction t, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = q.replaceAll(RegExp('[^0-9]'), '');
  return t.description.toLowerCase().contains(q) ||
      (t.note ?? '').toLowerCase().contains(q) ||
      (digits.isNotEmpty && t.amount.toString().contains(digits));
}

/// The rows in the order the person chose. [rows] arrive newest first.
///
/// Oldest reverses that, so days run oldest to newest. Largest sorts by amount, the biggest
/// first, and the newer entry first when two are equal.
List<Transaction> orderedRows(List<Transaction> rows, FilterOrder order) => switch (order) {
  FilterOrder.newest => rows,
  FilterOrder.oldest => rows.reversed.toList(),
  FilterOrder.largest =>
    [...rows]..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0 ? byAmount : b.occurredAt.compareTo(a.occurredAt);
    }),
};
