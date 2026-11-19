import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/fees.dart';
import 'package:akatabo/domain/insights.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

const _cash = {DefaultIds.cash};

/// A month of mixed entries: a payment with a fee, a withdrawal with fee and tax, a
/// purchase paid in cash with tax, and income with a fee that must not count.
List<Transaction> _mixed() => [
  txRow(id: 'pay', amount: 45000, fee: 1000, at: DateTime(2026, 11, 3, 9)),
  txRow(
    id: 'withdraw',
    direction: Direction.transfer,
    amount: 500000,
    fee: 1600,
    tax: 2500,
    toAccountId: DefaultIds.cash,
    at: DateTime(2026, 11, 5, 9),
  ),
  txRow(
    id: 'cash-buy',
    amount: 8000,
    tax: 400,
    accountId: DefaultIds.cash,
    at: DateTime(2026, 11, 6, 9),
  ),
  txRow(
    id: 'salary',
    direction: Direction.moneyIn,
    amount: 250000,
    fee: 999,
    categoryId: DefaultIds.salary,
    at: DateTime(2026, 11, 1, 9),
  ),
];

void main() {
  group('the three parts of fees and tax', () {
    test('sending, withdrawing and tax add back to the whole', () {
      final split = feeSplitOf(_mixed(), cashAccountIds: _cash);
      expect(split.sending, 1000);
      expect(split.withdrawing, 1600);
      expect(split.tax, 2900);
      expect(split.total, split.sending + split.withdrawing + split.tax);
      expect(split.total, 5500);
    });

    test('the total equals the Fees and tax share of money out', () {
      final rows = _mixed();
      final split = feeSplitOf(rows, cashAccountIds: _cash);
      expect(split.total, moneyOutByCategory(rows)[DefaultIds.fees]);
    });

    test('the parts by account add back to the total', () {
      final split = feeSplitOf(_mixed(), cashAccountIds: _cash);
      expect(split.byAccount.values.fold<int>(0, (a, b) => a + b), split.total);
      expect(split.byAccount[DefaultIds.mtn], 1000 + 1600 + 2500);
      expect(split.byAccount[DefaultIds.cash], 400);
    });

    test('a fee on a transfer to a non-cash account is sending money', () {
      final split = feeSplitOf([
        txRow(
          direction: Direction.transfer,
          amount: 100000,
          fee: 700,
          toAccountId: DefaultIds.bank,
        ),
      ], cashAccountIds: _cash);
      expect(split.sending, 700);
      expect(split.withdrawing, 0);
      expect(split.withdrawingCount, 0);
    });

    test('income never counts, even with a fee on it', () {
      final split = feeSplitOf([
        txRow(direction: Direction.moneyIn, amount: 1000, fee: 999, tax: 50),
      ], cashAccountIds: _cash);
      expect(split.total, 0);
    });

    test('tax is labelled as withdrawals only when all of it came from withdrawals', () {
      final onlyWithdrawals = feeSplitOf(
        _mixed().where((t) => t.id == 'withdraw'),
        cashAccountIds: _cash,
      );
      expect(onlyWithdrawals.taxIsAllFromWithdrawals, isTrue);

      final mixed = feeSplitOf(_mixed(), cashAccountIds: _cash);
      expect(mixed.taxIsAllFromWithdrawals, isFalse, reason: 'the cash purchase paid tax too');
    });

    test('counts and averages come from the rows that paid a fee', () {
      final split = feeSplitOf([
        txRow(id: 'a', amount: 45000, fee: 1000, at: DateTime(2026, 11, 3, 9)),
        txRow(id: 'b', amount: 20000, fee: 800, at: DateTime(2026, 11, 4, 9)),
        txRow(id: 'c', amount: 20000, at: DateTime(2026, 11, 5, 9)),
      ], cashAccountIds: _cash);
      expect(split.sendingCount, 2);
      expect(split.sending, 1800);
    });

    test('nothing to split gives an empty split', () {
      final split = feeSplitOf(const [], cashAccountIds: _cash);
      expect(split.total, 0);
      expect(split.taxIsAllFromWithdrawals, isFalse);
    });
  });

  group('category changes', () {
    test('the biggest change comes first, by size either way', () {
      final changes = categoryChanges(
        current: [
          txRow(amount: 100000),
          txRow(categoryId: DefaultIds.transport, amount: 56000),
        ],
        previous: [
          txRow(amount: 95000),
          txRow(categoryId: DefaultIds.transport, amount: 100000),
          txRow(categoryId: DefaultIds.bills, amount: 1000),
        ],
      );
      expect(changes.first.categoryId, DefaultIds.transport, reason: '-44,000 beats +5,000');
      expect(changes.first.change, -44000);
      expect(changes.first.percent, -44);
    });

    test('a category with nothing before has no percentage', () {
      final changes = categoryChanges(
        current: [txRow(categoryId: DefaultIds.family, amount: 30000)],
        previous: const [],
      );
      expect(changes.single.percent, isNull);
    });
  });
}
