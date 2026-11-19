import 'package:akatabo/features/add/when_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 19, 9, 14);

  group('whenLabel', () {
    test('today and yesterday by name, with the 24-hour time', () {
      expect(whenLabel(DateTime(2026, 11, 19, 9, 14), today), 'Today, 09:14');
      expect(whenLabel(DateTime(2026, 11, 18, 18, 40), today), 'Yesterday, 18:40');
    });

    test('an earlier day this year by weekday and date', () {
      expect(whenLabel(DateTime(2026, 11, 17, 14, 30), today), 'Tuesday 17 November, 14:30');
      expect(whenLabel(DateTime(2026, 1, 1, 0, 5), today), 'Thursday 1 January, 00:05');
    });

    test('a day in another year carries the year', () {
      expect(whenLabel(DateTime(2025, 12, 31, 23, 59), today), 'Wednesday 31 December 2025, 23:59');
    });

    test('yesterday across a month and a year boundary', () {
      expect(whenLabel(DateTime(2026, 12, 31, 8), DateTime(2027, 1, 1, 7)), 'Yesterday, 08:00');
    });

    test('the time of day does not move the day', () {
      // 23:59 yesterday is still yesterday at 00:01 today.
      expect(
        whenLabel(DateTime(2026, 11, 18, 23, 59), DateTime(2026, 11, 19, 0, 1)),
        'Yesterday, 23:59',
      );
    });
  });

  test('daysBefore counts calendar days', () {
    expect(daysBefore(DateTime(2026, 11, 19, 23), today), 0);
    expect(daysBefore(DateTime(2026, 11, 12), today), 7);
    expect(daysBefore(DateTime(2025, 11, 19), today), 365);
  });

  test('the earliest day is 1 January of last year', () {
    expect(earliestEntryDay(today), DateTime(2025));
    expect(earliestEntryDay(DateTime(2027, 2, 3)), DateTime(2026));
  });
}
