import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final food = txRow(id: 'food', amount: 20000, day: 20261119);
  final bills = txRow(
    id: 'bills',
    amount: 90000,
    categoryId: 'cat.bills',
    accountId: 'acct.cash',
    day: 20261105,
    fee: 1000,
  );
  final transfer = txRow(
    id: 'move',
    direction: Direction.transfer,
    amount: 50000,
    toAccountId: 'acct.cash',
    day: 20261110,
  );

  bool keep(Transaction t, {TransactionFilter f = const TransactionFilter(), Period? period}) =>
      matchesFilter(t, f, period);

  group('matchesFilter', () {
    test('an empty filter and no dates keep every entry', () {
      expect(keep(food), isTrue);
      expect(keep(bills), isTrue);
      expect(keep(transfer), isTrue);
    });

    test('a category keeps only its entries, and a transfer has none', () {
      const f = TransactionFilter(categoryIds: {'cat.food'});
      expect(keep(food, f: f), isTrue);
      expect(keep(bills, f: f), isFalse);
      expect(keep(transfer, f: f), isFalse);
    });

    test('accounts match the account money was paid from', () {
      const f = TransactionFilter(accountIds: {'acct.cash'});
      expect(keep(bills, f: f), isTrue);
      expect(keep(food, f: f), isFalse);
    });

    test('amount limits are inclusive on both sides', () {
      expect(keep(food, f: const TransactionFilter(minAmount: 20000)), isTrue);
      expect(keep(food, f: const TransactionFilter(minAmount: 20001)), isFalse);
      expect(keep(bills, f: const TransactionFilter(maxAmount: 90000)), isTrue);
      expect(keep(bills, f: const TransactionFilter(maxAmount: 89999)), isFalse);
    });

    test('only fees keeps entries with a fee above zero', () {
      const f = TransactionFilter(onlyFee: true);
      expect(keep(bills, f: f), isTrue);
      expect(keep(food, f: f), isFalse);
    });

    test('only unusual skips entries the person dismissed', () {
      const f = TransactionFilter(onlyUnusual: true);
      final flagged = txRow(id: 'odd').copyWith(flaggedUnusual: true);
      final dismissed = flagged.copyWith(flagDismissed: true);
      expect(keep(flagged, f: f), isTrue);
      expect(keep(dismissed, f: f), isFalse);
      expect(keep(food, f: f), isFalse);
    });

    test('a period keeps the days inside it, the last day included', () {
      final november = Period(DateTime(2026, 11), DateTime(2026, 12), PeriodKind.month);
      final firstWeek = Period(DateTime(2026, 11), DateTime(2026, 11, 8), PeriodKind.custom);
      expect(keep(bills, period: firstWeek), isTrue);
      expect(keep(food, period: firstWeek), isFalse);
      expect(keep(food, period: november), isTrue);
    });

    test('the choices combine: all must hold', () {
      const f = TransactionFilter(categoryIds: {'cat.bills'}, onlyFee: true, minAmount: 50000);
      expect(keep(bills, f: f), isTrue);
      const tooSmall = TransactionFilter(categoryIds: {'cat.bills'}, minAmount: 95000);
      expect(keep(bills, f: tooSmall), isFalse);
    });
  });

  group('the day view', () {
    test('listControlsOnly keeps the search and direction, and drops the Filters choices', () {
      const f = TransactionFilter(
        categoryIds: {'cat.bills'},
        onlyFee: true,
        query: 'tea',
        kind: TransactionKind.moneyOut,
      );
      final only = f.listControlsOnly;
      expect(only.categoryIds, isEmpty);
      expect(only.onlyFee, isFalse);
      expect(only.query, 'tea');
      expect(only.kind, TransactionKind.moneyOut);
      // An entry the Filters choices hide (wrong category, no fee) stays in the day view, because
      // the search word and the direction both match it.
      final tea = txRow(id: 'tea', description: 'Tea time');
      expect(keep(tea, f: f), isFalse);
      expect(keep(tea, f: only), isTrue);
    });
  });

  group('search and direction', () {
    test('the direction keeps money out or money in only', () {
      expect(keep(food, f: const TransactionFilter(kind: TransactionKind.moneyIn)), isFalse);
      expect(keep(food, f: const TransactionFilter(kind: TransactionKind.moneyOut)), isTrue);
      final income = txRow(id: 'pay', direction: Direction.moneyIn, amount: 250000);
      expect(keep(income, f: const TransactionFilter(kind: TransactionKind.moneyIn)), isTrue);
    });

    test('words match the description or note, ignoring case', () {
      final named = txRow(id: 'n', description: 'Yaka electricity', note: 'March bill');
      expect(keep(named, f: const TransactionFilter(query: 'YAKA')), isTrue);
      expect(keep(named, f: const TransactionFilter(query: 'march')), isTrue);
      expect(keep(named, f: const TransactionFilter(query: 'boda')), isFalse);
    });

    test('digits also match the amount', () {
      expect(keep(bills, f: const TransactionFilter(query: '9000')), isTrue);
      expect(keep(food, f: const TransactionFilter(query: '9000')), isFalse);
    });

    test('search and direction count as narrowing the list', () {
      expect(const TransactionFilter(query: '  ').anyNarrowing, isFalse);
      expect(const TransactionFilter(query: 'tea').anyNarrowing, isTrue);
      expect(const TransactionFilter(kind: TransactionKind.moneyOut).anyNarrowing, isTrue);
      // They are not Filters choices, so Clear all on the Filters screen does not hide them.
      expect(const TransactionFilter(query: 'tea').narrows, isFalse);
    });
  });

  group('narrows', () {
    test('the order alone does not narrow the list', () {
      expect(const TransactionFilter(order: FilterOrder.largest).narrows, isFalse);
      expect(const TransactionFilter(onlyFee: true).narrows, isTrue);
    });
  });

  group('orderedRows', () {
    // Rows arrive newest first.
    final rows = [
      txRow(id: 'a', amount: 5000, at: DateTime(2026, 11, 19, 9)),
      txRow(id: 'b', amount: 90000, at: DateTime(2026, 11, 18, 9)),
      txRow(id: 'c', amount: 90000, at: DateTime(2026, 11, 17, 9)),
    ];
    List<String> ids(List<Transaction> rs) => [for (final r in rs) r.id];

    test('newest keeps the order given', () {
      expect(ids(orderedRows(rows, FilterOrder.newest)), ['a', 'b', 'c']);
    });

    test('oldest reverses it', () {
      expect(ids(orderedRows(rows, FilterOrder.oldest)), ['c', 'b', 'a']);
    });

    test('largest sorts by amount, and the newer of two equal amounts first', () {
      expect(ids(orderedRows(rows, FilterOrder.largest)), ['b', 'c', 'a']);
    });

    test('does not change the list it was given', () {
      orderedRows(rows, FilterOrder.largest);
      expect(ids(rows), ['a', 'b', 'c']);
    });
  });
}
