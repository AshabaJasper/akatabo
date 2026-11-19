import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/forecast.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

final _today = DateTime(2026, 11, 19, 9, 14);
const _calc = PeriodCalculator();
final _month = _calc.month(_today); // 1 to 30 November 2026
final _window = rateWindow(_today); // 22 August to 19 November

/// One entry at noon on each of [count] days, starting at the first day of the rate window.
List<Transaction> _daily({
  required int count,
  required int amount,
  String idPrefix = 'd',
  String? categoryId = DefaultIds.food,
  String? regularPaymentId,
}) => [
  for (var i = 0; i < count; i++)
    txRow(
      id: '$idPrefix$i',
      amount: amount,
      categoryId: categoryId,
      regularPaymentId: regularPaymentId,
      at: DateTime(_window.start.year, _window.start.month, _window.start.day + i, 12),
    ),
];

/// One entry on each of 1 to 7 November: enough days for the gate to open.
List<Transaction> _sevenDaysThisMonth({int amount = 1000}) => [
  for (var d = 1; d <= 7; d++) txRow(id: 'm$d', amount: amount, at: DateTime(2026, 11, d, 12)),
];

Forecast? _forecast({
  required List<Transaction> monthRows,
  required List<Transaction> windowRows,
  List<RegularPayment> regular = const [],
}) => forecastFor(
  month: _month,
  today: _today,
  monthRows: monthRows,
  windowRows: windowRows,
  regular: regular,
);

void main() {
  group('the 7-day gate', () {
    test('no forecast with only six days of entries this month', () {
      final rows = [
        for (var d = 1; d <= 6; d++) txRow(amount: 1000, at: DateTime(2026, 11, d, 12)),
      ];
      expect(_forecast(monthRows: rows, windowRows: rows), isNull);
    });

    test('a forecast once seven different days have entries', () {
      final rows = _sevenDaysThisMonth();
      final f = _forecast(monthRows: rows, windowRows: rows);
      expect(f, isNotNull);
      expect(f!.spentSoFar, 7000);
    });

    test('several entries on one day count as one day', () {
      final rows = [
        for (var i = 0; i < 10; i++) txRow(amount: 1000, at: DateTime(2026, 11, 3, 9 + i % 5)),
      ];
      expect(_forecast(monthRows: rows, windowRows: rows), isNull);
    });
  });

  group('the everyday rate', () {
    test('is the everyday spend over the 90-day window, carried over the days left', () {
      final window = _daily(count: 90, amount: 9000);
      final monthRows = window.where((t) => _month.containsDay(t.localDay)).toList();
      final f = _forecast(monthRows: monthRows, windowRows: window)!;
      expect(f.dailyRate, 9000);
      expect(f.daysLeft, 11, reason: '20 to 30 November');
      expect(f.everydayToCome, 99000);
      expect(f.spentSoFar, 19 * 9000, reason: '1 to 19 November');
      expect(f.point, 19 * 9000 + 99000);
    });

    test('a one-off in a thin category is left out of the rate', () {
      // Twenty ordinary food entries of 9,000, and one 900,000 school term. School has a single
      // entry, so it takes the line of all spending pooled: the term is far above it.
      final window = [
        ..._daily(count: 20, amount: 9000),
        txRow(id: 'term', amount: 900000, categoryId: DefaultIds.school, at: _today),
      ];
      final f = _forecast(monthRows: _sevenDaysThisMonth(), windowRows: window)!;
      // 180,000 of ordinary spend over the 90 days is 2,000 a day. With the term it would be
      // (180,000 + 900,000) / 90 = 12,000 a day.
      expect(f.dailyRate, 2000);
    });

    test('with fewer than four entries in all, nothing is a one-off', () {
      final rows = [
        txRow(id: 'a', amount: 1000),
        txRow(id: 'b', amount: 1000),
        txRow(id: 'c', amount: 900000),
      ];
      expect(oneOffIds(rows), isEmpty);
    });

    test('a regular payment is never part of the everyday rate', () {
      final window = [
        ..._daily(count: 90, amount: 9000),
        ..._daily(
          count: 1,
          amount: 10000,
          idPrefix: 'bundle',
          categoryId: DefaultIds.bills,
          regularPaymentId: 'reg',
        ),
      ];
      final f = _forecast(monthRows: _sevenDaysThisMonth(amount: 9000), windowRows: window)!;
      expect(f.dailyRate, 9000, reason: 'the 10,000 bundle is left out');
    });

    test('with less history than the window, the rate is over the days since the first entry', () {
      final rows = _sevenDaysThisMonth();
      final f = _forecast(monthRows: rows, windowRows: rows)!;
      // The first entry was on 1 November, so the history is 19 days: 7,000 over 19 days.
      expect(f.dailyRate, (7000 / 19).round());
    });
  });

  group('regular payments still due', () {
    test('reproduce the drawn 96,000 for November', () {
      // Data bundle every 7 days from Sat 21 November: 21 and 28. Yaka every 9 days from
      // Tue 24: 24 only, since the next is 3 December. Water monthly from the 26th. School
      // fees each term, not due this month.
      final regular = [
        regularRow(id: 'bundle', nextDueOn: 20261121),
        regularRow(
          id: 'yaka',
          label: 'Yaka electricity',
          nextDueOn: 20261124,
          intervalDays: 9,
          typicalAmount: 30000,
        ),
        regularRow(
          id: 'water',
          label: 'Water bill',
          nextDueOn: 20261126,
          intervalDays: 30,
          typicalAmount: 46000,
        ),
        regularRow(
          id: 'school',
          label: 'School fees',
          nextDueOn: 20270215,
          intervalDays: 120,
          typicalAmount: 350000,
        ),
      ];
      final f = _forecast(
        monthRows: _sevenDaysThisMonth(),
        windowRows: _sevenDaysThisMonth(),
        regular: regular,
      )!;
      expect(f.regularDue, 96000);
    });

    test('a dismissed payment is never due', () {
      final p = regularRow(nextDueOn: 20261121, dismissed: true);
      expect(regularDuesIn(p, from: _today, through: _month.lastDate), isEmpty);
    });

    test('a due date before today is not counted again', () {
      final p = regularRow(nextDueOn: 20261110);
      final dues = regularDuesIn(p, from: _today, through: _month.lastDate);
      expect(dues.map(toLocalDay).toList(), [20261124]);
    });

    test('a zero interval never loops and is never due', () {
      final p = regularRow(nextDueOn: 20261121, intervalDays: 0);
      expect(regularDuesIn(p, from: _today, through: _month.lastDate), isEmpty);
    });
  });

  group('the range', () {
    test('contains the most likely figure, and has a band when spending varies', () {
      final window = [
        for (var i = 0; i < 90; i++)
          txRow(
            id: 'v$i',
            amount: i.isEven ? 4000 : 16000,
            at: DateTime(_window.start.year, _window.start.month, _window.start.day + i, 12),
          ),
      ];
      final monthRows = [
        for (final t in window)
          if (_month.containsDay(t.localDay)) t,
      ];
      final f = _forecast(
        monthRows: monthRows,
        windowRows: window,
        regular: [
          regularRow(
            nextDueOn: 20261125,
            typicalAmount: 30000,
            amountLow: 25000,
            amountHigh: 40000,
          ),
        ],
      )!;
      expect(f.low, lessThanOrEqualTo(f.point));
      expect(f.point, lessThanOrEqualTo(f.high));
      expect(f.low, lessThan(f.high));
      expect(f.low, greaterThanOrEqualTo(f.spentSoFar));
    });
  });

  group('phase 3 review fixes', () {
    test('a monthly bill keeps its day: after 1 December, the next is 1 January', () {
      final p = regularRow(nextDueOn: 20261201, intervalDays: monthlyIntervalDays);
      final dues = regularDuesIn(p, from: DateTime(2026, 12, 2), through: DateTime(2027, 1, 31));
      expect(dues.map(toLocalDay).toList(), [20270101]);
    });

    test('a bill on the 31st falls on the last day of shorter months, then returns', () {
      final p = regularRow(nextDueOn: 20270131, intervalDays: monthlyIntervalDays);
      final dues = regularDuesIn(p, from: DateTime(2027), through: DateTime(2027, 3, 31));
      expect(dues.map(toLocalDay).toList(), [20270131, 20270228, 20270331]);
    });

    test('a yearly payment keeps its date each year', () {
      final p = regularRow(nextDueOn: 20270215, intervalDays: yearlyIntervalDays);
      final dues = regularDuesIn(p, from: DateTime(2027), through: DateTime(2029, 12, 31));
      expect(dues.map(toLocalDay).toList(), [20270215, 20280215, 20290215]);
    });

    test('a payment due today is counted', () {
      final p = regularRow(
        label: 'Water bill',
        nextDueOn: 20261119,
        intervalDays: monthlyIntervalDays,
        typicalAmount: 46000,
      );
      final rows = _sevenDaysThisMonth();
      expect(_forecast(monthRows: rows, windowRows: rows, regular: [p])!.regularDue, 46000);
    });

    test('a payment due today that is already entered is not added again', () {
      final p = regularRow(
        label: 'Water bill',
        nextDueOn: 20261119,
        intervalDays: monthlyIntervalDays,
        typicalAmount: 46000,
      );
      final paid = txRow(
        id: 'water',
        amount: 46000,
        description: 'Water bill',
        categoryId: DefaultIds.bills,
        at: _today,
      );
      final rows = [..._sevenDaysThisMonth(), paid];
      final f = _forecast(monthRows: rows, windowRows: rows, regular: [p])!;
      expect(f.regularDue, 0);
      expect(f.spentSoFar, 7000 + 46000);
    });

    test("entries to a regular payment's payee stay out of the everyday rate", () {
      final window = [
        ..._daily(count: 90, amount: 9000),
        for (var w = 0; w < 13; w++)
          txRow(
            id: 'bundle$w',
            description: 'Data bundle',
            categoryId: DefaultIds.bills,
            at: DateTime(_window.start.year, _window.start.month, _window.start.day + w * 7, 15),
          ),
      ];
      final f = _forecast(
        monthRows: _sevenDaysThisMonth(amount: 9000),
        windowRows: window,
        regular: [regularRow(nextDueOn: 20261121)],
      )!;
      expect(f.dailyRate, 9000, reason: 'the bundle is counted once, as a regular payment');
    });

    test("before anything is spent today, today's everyday spending is still to come", () {
      // 9,000 a day up to yesterday and nothing yet today: a rate of 89 x 9,000 / 90 = 8,900.
      final window = _daily(count: 89, amount: 9000);
      final f = _forecast(monthRows: _sevenDaysThisMonth(), windowRows: window)!;
      expect(f.daysLeft, 11);
      expect(f.everydayToCome, 8900 * 12, reason: 'the rest of today plus 20 to 30 November');
    });

    test('when most amounts are the same, a slightly larger one is not a one-off', () {
      final rows = [
        for (var i = 0; i < 10; i++)
          txRow(id: 'ride$i', amount: 2000, categoryId: DefaultIds.transport),
        txRow(id: 'longer', amount: 3000, categoryId: DefaultIds.transport),
      ];
      expect(oneOffIds(rows), isNot(contains('longer')));
    });

    test('a school payment among identical daily amounts is still a one-off', () {
      final rows = [
        ..._daily(count: 30, amount: 9000),
        txRow(id: 'school', amount: 350000, categoryId: DefaultIds.school),
      ];
      expect(oneOffIds(rows), contains('school'));
    });
  });
}
