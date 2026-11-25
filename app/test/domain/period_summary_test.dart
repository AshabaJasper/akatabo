import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/goals.dart';
import 'package:akatabo/domain/period_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final week = Period(DateTime(2026, 11, 16), DateTime(2026, 11, 23), PeriodKind.week);

  test('out, in and net add up the entries, with fees and tax as money out', () {
    final s = summarisePeriod(
      period: week,
      rows: [
        txRow(id: 'a', amount: 40000, fee: 500, tax: 200),
        txRow(id: 'b', amount: 15000, categoryId: DefaultIds.transport),
        txRow(id: 'c', amount: 100000, direction: Direction.moneyIn, categoryId: null),
      ],
      previousRows: const [],
      goalMoves: const [],
    );
    expect(s.moneyOut, 55700);
    expect(s.moneyIn, 100000);
    expect(s.net, 44300);
    expect(s.isEmpty, isFalse);
  });

  test('the change is against the same days before, and null with nothing before', () {
    final before = [txRow(id: 'p', amount: 50000)];
    final now = [txRow(id: 'n', amount: 44000)];
    final s = summarisePeriod(period: week, rows: now, previousRows: before, goalMoves: const []);
    expect(s.previousOut, 50000);
    expect(s.change, -12);

    final first = summarisePeriod(
      period: week,
      rows: now,
      previousRows: const [],
      goalMoves: const [],
    );
    expect(first.change, isNull);
  });

  test('top categories are the three biggest, largest first, ties by id', () {
    final s = summarisePeriod(
      period: week,
      rows: [
        txRow(id: '1'),
        txRow(id: '2', amount: 30000, categoryId: DefaultIds.transport),
        txRow(id: '3', amount: 20000, categoryId: DefaultIds.bills),
        txRow(id: '4', amount: 20000, categoryId: DefaultIds.school),
        txRow(id: '5', amount: 5000, direction: Direction.moneyIn, categoryId: null),
      ],
      previousRows: const [],
      goalMoves: const [],
    );
    final ids = [for (final e in s.topCategories) e.key];
    expect(ids, hasLength(3));
    expect(ids.first, DefaultIds.transport);
    // Bills and school tie at 20,000; the order is by id, so it never flickers.
    expect(ids.sublist(1), ([DefaultIds.bills, DefaultIds.school]..sort()));
    expect(ids, isNot(contains(DefaultIds.food)));
  });

  test('goal money counts only moves inside the period, net of taking out', () {
    final s = summarisePeriod(
      period: week,
      rows: const [],
      previousRows: const [],
      goalMoves: const [
        GoalMoveEntry(amount: 30000, localDay: 20261116), // first day: in
        GoalMoveEntry(amount: -5000, localDay: 20261122), // last day: in
        GoalMoveEntry(amount: 70000, localDay: 20261115), // the day before: out
        GoalMoveEntry(amount: 90000, localDay: 20261123), // the day after: out
      ],
    );
    expect(s.setAside, 25000);
    expect(s.isEmpty, isTrue, reason: 'goal moves are not money in or out');
  });

  test('a period with no entries is empty and has no categories', () {
    final s = summarisePeriod(
      period: week,
      rows: const [],
      previousRows: const [],
      goalMoves: const [],
    );
    expect(s.isEmpty, isTrue);
    expect(s.topCategories, isEmpty);
    expect(s.net, 0);
  });
}
