import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/domain/goals.dart';
import 'package:flutter_test/flutter_test.dart';

GoalMoveEntry move(int amount, DateTime when) =>
    GoalMoveEntry(amount: amount, localDay: toLocalDay(when));

void main() {
  final today = DateTime(2026, 11, 24);

  group('progressOf', () {
    test('is the fraction saved, clamped between 0 and 1', () {
      expect(progressOf(target: 100000, saved: 25000), 0.25);
      expect(progressOf(target: 100000, saved: 150000), 1);
      expect(progressOf(target: 100000, saved: -5000), 0);
      expect(progressOf(target: 0, saved: 10), 0);
    });
  });

  group('milestonesCrossed', () {
    test('reports each milestone the move first reaches, in order', () {
      expect(milestonesCrossed(target: 100000, before: 20000, after: 60000), [25, 50]);
    });

    test('counts a milestone reached exactly', () {
      expect(milestonesCrossed(target: 100000, before: 0, after: 25000), [25]);
    });

    test('reports nothing when the move stays below the next milestone', () {
      expect(milestonesCrossed(target: 100000, before: 26000, after: 40000), isEmpty);
    });

    test('reports nothing for a take-out', () {
      expect(milestonesCrossed(target: 100000, before: 60000, after: 20000), isEmpty);
    });
  });

  group('roundUpToHundred', () {
    test('rounds any part of a hundred up', () {
      expect(roundUpToHundred(0), 0);
      expect(roundUpToHundred(1), 100);
      expect(roundUpToHundred(100), 100);
      expect(roundUpToHundred(101), 200);
    });
  });

  group('requiredPer', () {
    test('is null with no date', () {
      expect(
        requiredPer(target: 100000, saved: 0, targetDay: null, today: today, periodDays: 7),
        isNull,
      );
    });

    test('is zero once the target is reached', () {
      expect(
        requiredPer(
          target: 100000,
          saved: 100000,
          targetDay: 20270202,
          today: today,
          periodDays: 7,
        ),
        0,
      );
    });

    test('spreads the remainder over the weeks left, rounded up to 100', () {
      // 70 days to 2 February 2027 is exactly ten weeks: 100,000 / 10 = 10,000 a week.
      expect(
        requiredPer(target: 100000, saved: 0, targetDay: 20270202, today: today, periodDays: 7),
        10000,
      );
      // 100,001 over ten weeks is 10,000.1, which rounds up to 10,100.
      expect(
        requiredPer(target: 100001, saved: 0, targetDay: 20270202, today: today, periodDays: 7),
        10100,
      );
    });

    test('asks for the whole remainder, not more, inside the last week', () {
      // 3 days left: dividing by 3/7 of a week used to ask for 233,400.
      expect(
        requiredPer(target: 100000, saved: 0, targetDay: 20261127, today: today, periodDays: 7),
        100000,
      );
    });

    test('asks for the whole remainder inside the last month', () {
      expect(
        requiredPer(target: 70000, saved: 0, targetDay: 20261130, today: today, periodDays: 30),
        70000,
      );
    });

    test('does not round up an extra 100 from floating-point error', () {
      // 700 over 45 days, monthly: ceil(700 * 30 / 45) = 467, so 500.
      expect(
        requiredPer(target: 700, saved: 0, targetDay: 20270108, today: today, periodDays: 30),
        500,
      );
    });

    test('asks for the whole remainder when the date has passed', () {
      expect(
        requiredPer(target: 100001, saved: 0, targetDay: 20261101, today: today, periodDays: 7),
        100100,
      );
    });
  });

  group('projectReach', () {
    test('gives no date with fewer than three adds', () {
      final moves = [
        move(10000, today.subtract(const Duration(days: 30))),
        move(10000, today.subtract(const Duration(days: 40))),
      ];
      expect(projectReach(target: 200000, saved: 20000, moves: moves, today: today), isNull);
    });

    test('gives no date with less than three weeks of history', () {
      final moves = [
        move(10000, today.subtract(const Duration(days: 2))),
        move(10000, today.subtract(const Duration(days: 1))),
        move(10000, today),
      ];
      expect(projectReach(target: 200000, saved: 30000, moves: moves, today: today), isNull);
    });

    test('projects a steady saver exactly, with no spread', () {
      // Ten thousand every week for the last eight weeks: 80,000 in all. 120,000 is left,
      // so twelve more weeks, which is 84 days.
      final moves = [
        for (var k = 0; k < 8; k++) move(10000, today.subtract(Duration(days: 7 * k))),
      ];
      final p = projectReach(target: 200000, saved: 80000, moves: moves, today: today)!;
      expect(p.weeklyRate, 10000);
      expect(p.point, today.add(const Duration(days: 84)));
      expect(p.early, p.point);
      expect(p.late, p.point);
    });

    test('gives no late date when the weakest weeks put nothing aside', () {
      // Three deposits in one week, three weeks ago, and nothing since.
      final moves = [
        move(10000, today.subtract(const Duration(days: 22))),
        move(10000, today.subtract(const Duration(days: 23))),
        move(10000, today.subtract(const Duration(days: 24))),
      ];
      final p = projectReach(target: 200000, saved: 30000, moves: moves, today: today)!;
      expect(p.late, isNull);
      // The strongest weeks saved more than the average, so they reach the goal sooner.
      expect(p.early.isBefore(p.point), isTrue);
    });

    test('uses only the weeks since the first add for a new saver', () {
      // 10,000 a week for four weeks, the first add 21 days ago. Counting the four weeks
      // before the goal existed used to report 5,000 a week.
      final moves = [
        for (var k = 0; k < 4; k++) move(10000, today.subtract(Duration(days: 7 * k))),
      ];
      final p = projectReach(target: 140000, saved: 40000, moves: moves, today: today)!;
      expect(p.weeklyRate, 10000);
      expect(p.point, today.add(const Duration(days: 70)));
      expect(p.late, isNotNull);
    });

    test('gives no date when more was taken out than put in lately', () {
      // Old adds meet the history gates but fall outside the eight-week window.
      final moves = [
        move(10000, today.subtract(const Duration(days: 70))),
        move(10000, today.subtract(const Duration(days: 77))),
        move(10000, today.subtract(const Duration(days: 84))),
        move(50000, today.subtract(const Duration(days: 14))),
        move(-60000, today.subtract(const Duration(days: 7))),
      ];
      expect(projectReach(target: 200000, saved: 20000, moves: moves, today: today), isNull);
    });

    test('gives no projection once the goal is reached', () {
      final moves = [
        for (var k = 0; k < 8; k++) move(10000, today.subtract(Duration(days: 7 * k))),
      ];
      expect(projectReach(target: 80000, saved: 80000, moves: moves, today: today), isNull);
    });
  });
}
