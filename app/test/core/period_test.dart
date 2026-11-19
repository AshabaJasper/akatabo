import 'package:akatabo/core/time/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 19, 9, 14); // a Thursday
  const calc = PeriodCalculator();

  test('local day round-trips', () {
    expect(toLocalDay(today), 20261119);
    expect(fromLocalDay(20261119), DateTime(2026, 11, 19));
  });

  test('a calendar month runs from the 1st to the 1st', () {
    final m = calc.month(today);
    expect(m.start, DateTime(2026, 11));
    expect(m.end, DateTime(2026, 12));
    expect(m.lengthInDays, 30);
    expect(m.containsDay(20261130), isTrue);
    expect(m.containsDay(20261201), isFalse);
  });

  test('a month starting on the 25th spans two calendar months', () {
    const salary = PeriodCalculator(monthStartsOn: 25);
    expect(salary.month(today).start, DateTime(2026, 10, 25));
    expect(salary.month(today).end, DateTime(2026, 11, 25));
    expect(salary.month(DateTime(2026, 11, 25)).start, DateTime(2026, 11, 25));
    expect(salary.month(DateTime(2027, 1, 3)).start, DateTime(2026, 12, 25));
  });

  test('the week starts on the chosen day', () {
    expect(calc.week(today).start, DateTime(2026, 11, 15)); // Sunday
    const monday = PeriodCalculator(weekStartsOn: DateTime.monday);
    expect(monday.week(today).start, DateTime(2026, 11, 16));
    expect(monday.week(DateTime(2026, 11, 16)).start, DateTime(2026, 11, 16));
    expect(calc.week(today).lengthInDays, 7);
  });

  test('quarters and years follow the month rule', () {
    expect(calc.quarter(today).start, DateTime(2026, 10));
    expect(calc.quarter(today).end, DateTime(2027));
    expect(calc.year(today).start, DateTime(2026));
    expect(calc.year(today).lengthInDays, 365);
  });

  test('previous and next step one period', () {
    final nov = calc.month(today);
    expect(calc.previous(nov).start, DateTime(2026, 10));
    expect(calc.next(nov).start, DateTime(2026, 12));
    expect(calc.previous(calc.month(DateTime(2026, 1, 5))).start, DateTime(2025, 12));
  });

  test('elapsed days count today and stop at the period edges', () {
    final nov = calc.month(today);
    expect(calc.elapsedDays(nov, today), 19);
    expect(calc.elapsedDays(nov, DateTime(2026, 10, 2)), 0);
    expect(calc.elapsedDays(nov, DateTime(2027, 2)), 30);
  });

  group('a change "on October" compares the same number of days', () {
    test('19 days of November against 1 to 19 October', () {
      final same = calc.sameDaysOfPrevious(calc.month(today), today);
      expect(same.start, DateTime(2026, 10));
      expect(same.end, DateTime(2026, 10, 20));
      expect(same.lengthInDays, 19);
    });

    test('never runs past a shorter previous month', () {
      final mar31 = DateTime(2026, 3, 31);
      final same = calc.sameDaysOfPrevious(calc.month(mar31), mar31);
      expect(same.end, DateTime(2026, 3));
      expect(same.lengthInDays, 28);
    });
  });

  // Uganda has no daylight saving, so this cannot fail on this machine; it guards phones set
  // to a zone that has it, and CI run with such a TZ.
  test('stepping a day is a calendar day on every day of the year', () {
    for (var d = DateTime(2026); d.year == 2026; d = addDays(d, 1)) {
      expect(calc.previous(calc.day(d)).start, DateTime(d.year, d.month, d.day - 1));
      expect(calc.day(d).lastDate, dateOnly(d));
      expect(calc.next(calc.day(d)).start, DateTime(d.year, d.month, d.day + 1));
    }
  });

  test('a period must end after it starts', () {
    expect(() => Period(today, today, PeriodKind.custom), throwsArgumentError);
  });
}
