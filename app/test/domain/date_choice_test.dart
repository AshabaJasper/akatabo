import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/domain/date_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday 19 November 2026, with weeks from Sunday and months from the 1st.
  final today = DateTime(2026, 11, 19);
  const calc = PeriodCalculator();

  group('presets', () {
    test('last 7 days ends today and starts six days before it', () {
      final p = presetPeriod(DatePreset.last7Days, today, calc);
      expect(p.start, DateTime(2026, 11, 13));
      expect(p.lastDate, DateTime(2026, 11, 19));
      expect(p.lengthInDays, 7);
    });

    test('this month and last month follow the calendar', () {
      final now = presetPeriod(DatePreset.thisMonth, today, calc);
      expect(now.start, DateTime(2026, 11));
      expect(now.lengthInDays, 30);

      final last = presetPeriod(DatePreset.lastMonth, today, calc);
      expect(last.start, DateTime(2026, 10));
      expect(last.lastDate, DateTime(2026, 10, 31));
    });

    test('last 3 months runs from the start of two months back to the end of this month', () {
      final p = presetPeriod(DatePreset.last3Months, today, calc);
      expect(p.start, DateTime(2026, 9));
      expect(p.lastDate, DateTime(2026, 11, 30));
      expect(p.lengthInDays, 91);
    });

    test('this year runs from 1 January to 31 December', () {
      final p = presetPeriod(DatePreset.thisYear, today, calc);
      expect(p.start, DateTime(2026));
      expect(p.lastDate, DateTime(2026, 12, 31));
    });

    test('custom has no preset rule and is refused', () {
      expect(() => presetPeriod(DatePreset.custom, today, calc), throwsArgumentError);
    });
  });

  group('custom range', () {
    test('counts both ends', () {
      expect(inclusiveDays(DateTime(2026, 11, 5), DateTime(2026, 11, 19)), 15);
      expect(inclusiveDays(DateTime(2026, 11, 5), DateTime(2026, 11, 5)), 1);
    });

    test('a tap on a longer range starts a new one-day range there', () {
      final p = pickDay(DateTime(2026, 11), DateTime(2026, 11, 30), DateTime(2026, 11, 10));
      expect(p.first, DateTime(2026, 11, 10));
      expect(p.last, DateTime(2026, 11, 10));
    });

    test('the start can move later: 10 to 15 November from 1 to 30 November', () {
      var p = pickDay(DateTime(2026, 11), DateTime(2026, 11, 30), DateTime(2026, 11, 10));
      p = pickDay(p.first, p.last, DateTime(2026, 11, 15));
      expect(p.first, DateTime(2026, 11, 10));
      expect(p.last, DateTime(2026, 11, 15));
    });

    test('on a one-day range, a tap before it moves the start', () {
      final p = pickDay(DateTime(2026, 11, 10), DateTime(2026, 11, 10), DateTime(2026, 11, 2));
      expect(p.first, DateTime(2026, 11, 2));
      expect(p.last, DateTime(2026, 11, 10));
    });

    test('on a one-day range, a tap on the same day keeps one day', () {
      final p = pickDay(DateTime(2026, 11, 10), DateTime(2026, 11, 10), DateTime(2026, 11, 10));
      expect(p.first, DateTime(2026, 11, 10));
      expect(p.last, DateTime(2026, 11, 10));
    });

    test('ignores the time of day on the tapped day', () {
      final p = pickDay(
        DateTime(2026, 11, 5, 14),
        DateTime(2026, 11, 5, 9),
        DateTime(2026, 11, 8, 23, 30),
      );
      expect(p.first, DateTime(2026, 11, 5));
      expect(p.last, DateTime(2026, 11, 8));
    });
  });
}
