import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/domain/forecast.dart';
import 'package:akatabo/widgets/charts/cumulative_line.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('safe to spend per day', () {
    test('shares the income left after the forecast over the days left', () {
      final s = safeToSpend(moneyIn: 1650000, forecastPoint: 1500000, daysLeft: 10);
      expect(s, isA<SafeAmount>());
      expect((s! as SafeAmount).perDay, 15000);
    });

    test('rounds down to whole shillings', () {
      final s = safeToSpend(moneyIn: 1000, forecastPoint: 0, daysLeft: 3);
      expect((s! as SafeAmount).perDay, 333);
    });

    test('says how much over the income the forecast is', () {
      final s = safeToSpend(moneyIn: 1000000, forecastPoint: 1175000, daysLeft: 8);
      expect(s, isA<OverBy>());
      expect((s! as OverBy).amount, 175000);
    });

    test('is exactly zero when the forecast equals the income', () {
      final s = safeToSpend(moneyIn: 500000, forecastPoint: 500000, daysLeft: 4);
      expect((s! as SafeAmount).perDay, 0);
    });

    test('is not shown without income recorded this month', () {
      expect(safeToSpend(moneyIn: 0, forecastPoint: 300000, daysLeft: 10), isNull);
    });

    test('is not shown on the last day, when nothing is left to spread over', () {
      expect(safeToSpend(moneyIn: 900000, forecastPoint: 300000, daysLeft: 0), isNull);
    });
  });

  group('pace against last month', () {
    test('is the difference between this month and the same days last month', () {
      final p = paceVsLast(thisMonth: 900000, lastMonth: 750000);
      expect(p!.difference, 150000);
    });

    test('is negative when this month is spending less', () {
      final p = paceVsLast(thisMonth: 400000, lastMonth: 750000);
      expect(p!.difference, -350000);
    });

    test('is not shown when last month had no spending by then to compare with', () {
      expect(paceVsLast(thisMonth: 400000, lastMonth: 0), isNull);
    });
  });

  test('a regular payment due this month carries its name and due day', () {
    final due = RegularDue(
      label: 'Yaka electricity',
      due: DateTime(2026, 11, 28),
      low: 20000,
      typical: 30000,
      high: 40000,
    );
    expect(due.label, 'Yaka electricity');
    expect(due.due.day, 28);
    expect(due.low <= due.typical && due.typical <= due.high, isTrue);
  });

  group('where the forecast passes income', () {
    test('marks the first day money out reaches income', () {
      expect(passesIncomeAt([100, 200, 300, 400], 250), 2);
    });

    test('marks nothing when money out is already above income today', () {
      expect(passesIncomeAt([300, 400], 250), isNull);
    });

    test('marks nothing when the forecast stays under income', () {
      expect(passesIncomeAt([100, 150], 250), isNull);
    });
  });

  test('the one-offs it lists are the ones the rate left out, picked across the window', () {
    final today = DateTime(2026, 11, 19, 9);
    final month = const PeriodCalculator().month(today);
    final window = rateWindow(today);
    final history = [
      for (var i = 0; i < 60; i++)
        txRow(
          id: 'd$i',

          at: DateTime(window.start.year, window.start.month, window.start.day + i, 12),
        ),
    ];
    final monthRows = [
      for (var d = 1; d <= 7; d++) txRow(id: 'm$d', at: DateTime(2026, 11, d, 12)),
      txRow(id: 'school', amount: 900000, at: DateTime(2026, 11, 8, 12)),
    ];
    final windowRows = [...history, ...monthRows];
    final f = forecastFor(
      month: month,
      today: today,
      monthRows: monthRows,
      windowRows: windowRows,
      regular: const [],
    )!;
    expect(f.oneOffs, oneOffIds(windowRows));
    expect(f.oneOffs, contains('school'));
  });
}
