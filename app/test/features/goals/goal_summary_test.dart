import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/goals/goal_summary.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GoalRepository goals;
  final today = DateTime(2026, 11, 24, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    goals = GoalRepository(db);
  });
  tearDown(() => db.close());

  /// Moves recorded on [day], as the repository saves them.
  Future<void> moveOn(DateTime day, String goalId, int amount, {String account = DefaultIds.mtn}) =>
      withClock(
        Clock.fixed(day),
        () => goals.addMove(goalId: goalId, accountId: account, amount: amount),
      );

  Future<Goal> goalRow(String id) async => (await goals.watchById(id).first)!;
  Future<List<GoalMove>> movesOf(String id) => goals.watchMoves(id).first;

  test(
    'a goal with its target met is reached, with no pace, and its milestones all on one day',
    () async {
      final id = await goals.add(
        name: 'Phone',
        target: 50000,
        colourToken: 'cat-teal',
        targetDay: 20990101,
      );
      await moveOn(DateTime(2026, 11, 20), id, 50000);
      final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
      expect(s.standing, GoalStanding.reached);
      expect(s.weekly, 0);
      expect(s.projection, isNull);
      expect(s.progress, 1);
      expect(s.milestoneDays.keys, containsAll([25, 50, 75, 100]));
      expect(s.milestoneDays.values.toSet(), {20261120});
    },
  );

  test('a goal with no date has no pace to judge', () async {
    final id = await goals.add(name: 'Sewing', target: 600000, colourToken: 'cat-amber');
    await moveOn(DateTime(2026, 11, 20), id, 10000);
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.standing, GoalStanding.noDate);
    expect(s.weekly, isNull);
  });

  test('a goal with a date but thin history is too early to judge', () async {
    final id = await goals.add(
      name: 'Fees',
      target: 1000000,
      colourToken: 'cat-teal',
      targetDay: 20990101,
    );
    await moveOn(DateTime(2026, 11, 20), id, 10000);
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.standing, GoalStanding.tooEarly);
    expect(s.weekly, isNotNull, reason: 'the amount to put aside is still known');
  });

  test('steady saving that keeps up with the date is on pace', () async {
    final id = await goals.add(
      name: 'Fees',
      target: 1000000,
      colourToken: 'cat-teal',
      targetDay: 20270601,
    );
    for (var week = 0; week < 8; week++) {
      await moveOn(DateTime(2026, 11, 24).subtract(Duration(days: week * 7 + 1)), id, 40000);
    }
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.projection, isNotNull);
    expect(s.standing, GoalStanding.onPace);
  });

  test('saving too little for the date is a little behind', () async {
    final id = await goals.add(
      name: 'Fees',
      target: 1000000,
      colourToken: 'cat-teal',
      targetDay: 20261226,
    );
    for (var week = 0; week < 8; week++) {
      await moveOn(DateTime(2026, 11, 24).subtract(Duration(days: week * 7 + 1)), id, 40000);
    }
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.projection, isNotNull);
    expect(s.standing, GoalStanding.behind);
  });

  test('each milestone keeps the first day it was crossed', () async {
    final id = await goals.add(
      name: 'Fees',
      target: 100000,
      colourToken: 'cat-teal',
      targetDay: 20990101,
    );
    await moveOn(DateTime(2026, 11), id, 30000);
    await moveOn(DateTime(2026, 11, 10), id, 30000);
    await moveOn(DateTime(2026, 11, 12), id, -40000);
    await moveOn(DateTime(2026, 11, 20), id, 30000);
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.milestoneDays[25], 20261101);
    expect(s.milestoneDays[50], 20261110, reason: 'crossed again later, the first day stands');
    expect(s.milestoneDays.containsKey(75), isFalse);
  });

  test('#7 the projection says how many weeks it averaged: 4 at three weeks of history', () async {
    final id = await goals.add(name: 'Fees', target: 1000000, colourToken: 'cat-teal');
    await moveOn(DateTime(2026, 11, 3), id, 10000);
    await moveOn(DateTime(2026, 11, 10), id, 10000);
    await moveOn(DateTime(2026, 11, 17), id, 10000);
    final s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.projection, isNotNull);
    expect(s.projection!.windowWeeks, 4, reason: 'not the 8-week maximum');
  });

  test('a date already gone is flagged as passed; a reached goal never is', () async {
    final id = await withClock(
      Clock.fixed(DateTime(2026)),
      () => goals.add(name: 'Rent', target: 50000, colourToken: 'cat-teal', targetDay: 20260301),
    );
    await moveOn(DateTime(2026, 11, 20), id, 10000);
    var s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.datePassed, isTrue);
    expect(s.remaining, 40000);

    await moveOn(DateTime(2026, 11, 21), id, 40000);
    s = summariseGoal(goal: await goalRow(id), moves: await movesOf(id), today: today);
    expect(s.datePassed, isFalse);
  });

  test('money per account adds up each account on its own', () async {
    final id = await goals.add(name: 'Fees', target: 100000, colourToken: 'cat-teal');
    await moveOn(DateTime(2026, 11), id, 30000);
    await moveOn(DateTime(2026, 11, 2), id, 20000, account: DefaultIds.cash);
    await moveOn(DateTime(2026, 11, 3), id, -5000);
    expect(savedByAccount(await movesOf(id)), {DefaultIds.mtn: 25000, DefaultIds.cash: 20000});
  });
}
