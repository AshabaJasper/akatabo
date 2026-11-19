import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/calendar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);
const _calc = PeriodCalculator();

/// The drawn November: money out in thousands for the 1st to the 19th.
const _drawn = [38, 48, 39, 41, 45, 62, 115, 36, 44, 40, 38, 46, 60, 87, 30, 398, 34, 30, 53];

/// The step each drawn day is shaded with (0 lightest, 3 darkest).
const _drawnSteps = [0, 1, 0, 1, 1, 2, 3, 0, 1, 1, 0, 1, 2, 2, 0, 3, 0, 0, 1];

void main() {
  group('heat steps', () {
    test('rank-based steps shade the drawn November exactly as drawn', () {
      final amounts = [for (final k in _drawn) k * 1000];
      for (var i = 0; i < amounts.length; i++) {
        expect(heatStep(amounts[i], amounts), _drawnSteps[i], reason: 'day ${i + 1}');
      }
    });

    test('one huge day does not wash the rest of the month out', () {
      final days = [10000, 20000, 30000, 40000, 5000000];
      expect(heatStep(40000, days), greaterThan(0));
    });

    test('a day with nothing spent is the lightest step', () {
      expect(heatStep(0, [1000, 2000]), 0);
      expect(heatStep(5000, const []), 0);
    });
  });

  group('marks', () {
    test('past, current and future follow now', () {
      final month = _calc.month(_now);
      final marks = dayMarks(month, const {}, _now);
      expect(marks, hasLength(30));
      expect(marks[17].state, MarkState.past, reason: '18 November');
      expect(marks[18].state, MarkState.current, reason: '19 November');
      expect(marks[19].state, MarkState.future, reason: '20 November');
    });

    test('money out per day counts fees, and transfers only by their fee and tax', () {
      final rows = [
        txRow(id: 'a', amount: 45000, fee: 1000),
        txRow(
          id: 'b',
          direction: Direction.transfer,
          amount: 25000,
          fee: 1500,
          tax: 900,
          toAccountId: DefaultIds.cash,
        ),
        txRow(id: 'c', direction: Direction.moneyIn, amount: 250000),
      ];
      expect(moneyOutByDay(rows), {20261119: 45000 + 1000 + 1500 + 900});
    });

    test('hours place each entry at the hour it happened', () {
      final rows = [
        txRow(id: 'a', amount: 8000, at: DateTime(2026, 11, 19, 8, 2)),
        txRow(id: 'b', amount: 45000, at: DateTime(2026, 11, 19, 9, 14)),
        txRow(id: 'c', amount: 9000, at: DateTime(2026, 11, 18, 9, 30)),
      ];
      final hours = hourMarks(DateTime(2026, 11, 19), rows, _now);
      expect(hours, hasLength(24));
      expect(hours[8].moneyOut, 8000);
      expect(hours[9].moneyOut, 45000, reason: 'the 18th is a different day');
      expect(hours[9].state, MarkState.current);
      expect(hours[10].state, MarkState.future);
    });

    test('weeks of a quarter add back to the quarter', () {
      final quarter = _calc.quarter(_now);
      final byDay = {
        for (var d = quarter.start; d.isBefore(quarter.end); d = addDays(d, 3)) toLocalDay(d): 1000,
      };
      final weeks = weekMarks(quarter, byDay, _now, _calc);
      final total = byDay.values.fold<int>(0, (a, b) => a + b);
      expect(weeks.fold<int>(0, (a, w) => a + w.moneyOut), total);
      expect(weeks.first.start, quarter.start);
      expect(weeks.last.end, quarter.end);
      expect(weeks.where((w) => w.state == MarkState.current), hasLength(1));
    });

    test('a year has twelve months, ending at the current month', () {
      final months = monthMarks(_calc.year(_now), const {}, _now, _calc);
      expect(months, hasLength(12));
      expect(months[10].state, MarkState.current, reason: 'November');
      expect(months[11].state, MarkState.future, reason: 'December');
    });

    test('months follow "Month starts on"', () {
      const calc = PeriodCalculator(monthStartsOn: 25);
      final months = monthMarks(calc.year(_now), const {}, _now, calc);
      expect(months, hasLength(12));
      expect(months.first.start, DateTime(2026, 1, 25));
    });
  });

  group('year summary', () {
    CalendarMark month(int m, int out, MarkState s) =>
        CalendarMark(start: DateTime(2026, m), end: DateTime(2026, m + 1), moneyOut: out, state: s);

    test('needs two ended months', () {
      expect(
        summariseYear([month(1, 100, MarkState.past), month(2, 50, MarkState.current)]),
        isNull,
      );
    });

    test('months before the first entry are not counted as months of nothing', () {
      final s = summariseYear([
        month(1, 0, MarkState.past),
        month(2, 0, MarkState.past),
        month(3, 400, MarkState.past),
        month(4, 200, MarkState.past),
        month(5, 0, MarkState.current),
      ])!;
      expect(s.lowest.start.month, 4, reason: 'January and February came before any entry');
      expect(s.usual, 300);
    });

    test('nothing to say for a year without entries', () {
      expect(summariseYear([month(1, 0, MarkState.past), month(2, 0, MarkState.past)]), isNull);
    });

    test('names the highest and lowest ended month and the median', () {
      final s = summariseYear([
        month(1, 300, MarkState.past),
        month(2, 100, MarkState.past),
        month(3, 200, MarkState.past),
        month(4, 900, MarkState.current),
      ])!;
      expect(s.highest.start.month, 1);
      expect(s.lowest.start.month, 2);
      expect(s.usual, 200, reason: 'the current month is not yet usual');
    });
  });
}
