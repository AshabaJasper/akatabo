import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:akatabo/services/notifications/reminder_scheduler.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notifications.dart';

void main() {
  test('a goal that asks for reminders is scheduled with what to put aside', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final fake = FakeNotifications();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationsServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final goals = GoalRepository(db);
    final today = DateTime(2026, 11, 19, 10);

    await withClock(Clock.fixed(today), () async {
      // 800,000 to reach by 31 December: 100,000 saved, so 700,000 left over 42 days.
      final phone = await goals.add(
        name: 'Phone',
        target: 800000,
        colourToken: 'cat-teal',
        targetDay: 20261231,
        remindEvery: GoalRemind.weekly,
      );
      await goals.addMove(goalId: phone, accountId: 'acct.mtn', amount: 100000);
      // Set to Off: no reminder.
      await goals.add(name: 'Land', target: 500000, colourToken: 'cat-teal');
      // Already reached: no reminder either.
      final done = await goals.add(
        name: 'Done',
        target: 10000,
        colourToken: 'cat-teal',
        remindEvery: GoalRemind.weekly,
      );
      await goals.addMove(goalId: done, accountId: 'acct.mtn', amount: 10000);

      await container.read(reminderSchedulerProvider).sync();
    });

    final plan = fake.scheduled!;
    expect(plan.map((r) => r.title), ['Set aside for Phone']);
    final weekly = plan.single as WeeklyReminder;
    expect(weekly.id, ReminderIds.goalFirst);
    expect(weekly.body, 'Put aside about UGX 116,700 for Phone this week.');
  });

  test('after start, saving a goal or giving it money sets the reminders again', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final fake = FakeNotifications();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationsServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    Future<void> waitFor(int replaces) async {
      for (var i = 0; i < 100 && fake.replaces < replaces; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await rescheduleRemindersAtStart(container);
    expect(fake.scheduled, isEmpty);

    final goals = GoalRepository(db);
    final id = await goals.add(
      name: 'Phone',
      target: 800000,
      colourToken: 'cat-teal',
      remindEvery: GoalRemind.monthly,
    );
    await waitFor(2);
    expect(fake.scheduled!.whereType<MonthlyReminder>().single.title, 'Set aside for Phone');

    // Reaching the target ends the reminder.
    final before = fake.replaces;
    await goals.addMove(goalId: id, accountId: 'acct.mtn', amount: 800000);
    await waitFor(before + 1);
    expect(fake.scheduled, isEmpty);
  });
}
