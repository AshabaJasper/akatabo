import 'package:akatabo/data/db/tables.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('money out', () {
    test('a spending entry costs its amount plus fee plus tax', () {
      final t = txRow(amount: 45000, fee: 1000, tax: 500);
      expect(moneyOutOf(t), 46500);
      expect(totalCostOf(t), 46500);
    });

    test('money in takes nothing out', () {
      final t = txRow(direction: Direction.moneyIn, amount: 250000, categoryId: DefaultIds.salary);
      expect(moneyOutOf(t), 0);
      expect(moneyInOf(t), 250000);
    });

    test('a transfer counts only its fee and tax as money out (owner decision 1)', () {
      final t = txRow(
        direction: Direction.transfer,
        amount: 100000,
        fee: 1500,
        toAccountId: DefaultIds.cash,
      );
      expect(moneyOutOf(t), 1500);
      expect(moneyInOf(t), 0);
      expect(totalCostOf(t), 101500, reason: 'total cost still includes the moved amount');
    });
  });

  group('period totals', () {
    final rows = [
      txRow(id: 'a', amount: 45000, fee: 1000),
      txRow(id: 'b', amount: 200000, tax: 2000, categoryId: DefaultIds.school),
      txRow(id: 'c', direction: Direction.moneyIn, amount: 250000),
      txRow(
        id: 'd',
        direction: Direction.transfer,
        amount: 80000,
        fee: 500,
        toAccountId: DefaultIds.cash,
      ),
    ];

    test('money out is the sum of out amounts with their fees and tax', () {
      final totals = totalsOf(rows);
      expect(totals.moneyOut, 46000 + 202000 + 500);
      expect(totals.moneyIn, 250000);
      expect(totals.net, 250000 - 248500);
    });

    test('category shares add back to money out, with fees and tax in their own part', () {
      final parts = moneyOutByCategory(rows);
      expect(parts[DefaultIds.food], 45000);
      expect(parts[DefaultIds.school], 200000);
      expect(parts[DefaultIds.fees], 1000 + 2000 + 500);
      expect(parts.values.fold<int>(0, (a, b) => a + b), totalsOf(rows).moneyOut);
      expect(parts.containsKey(DefaultIds.salary), isFalse, reason: 'income is not spending');
    });

    test('an empty period has zero totals and no parts', () {
      expect(totalsOf(const []).moneyOut, 0);
      expect(moneyOutByCategory(const []), isEmpty);
    });
  });

  group('same days comparison', () {
    test('only the first N days of the previous period are summed', () {
      final previous = [
        txRow(id: '1', day: 20261001),
        txRow(id: '2', amount: 20000, day: 20261003),
        txRow(id: '3', amount: 99999, day: 20261015), // after the 3rd, so not counted
      ];
      expect(moneyOutOnDays(previous, startDay: 20261001, days: 3), 30000);
    });

    test('percentage change is null without a previous figure', () {
      expect(percentChange(current: 500, previous: 0), isNull);
    });

    test('percentage change rounds to a whole number', () {
      expect(percentChange(current: 131, previous: 100), 31);
      expect(percentChange(current: 88, previous: 100), -12);
    });
  });
}
