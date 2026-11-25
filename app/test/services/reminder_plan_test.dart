import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _settings(Map<SettingKey<Object>, Object> values) => {
  for (final e in values.entries) e.key.name: _encode(e.key, e.value),
};

String _encode(SettingKey<Object> key, Object value) => switch (key) {
  BoolSetting() => (value as bool) ? '1' : '0',
  _ => '$value',
};

void main() {
  // Thursday 19 November 2026, 10:15.
  final now = DateTime(2026, 11, 19, 10, 15);

  group('planReminders', () {
    test('nothing is planned with the defaults: every reminder starts off', () {
      expect(planReminders(settings: const {}, now: now), isEmpty);
    });

    test('the daily reminder uses the chosen time', () {
      final plan = planReminders(
        settings: _settings({SettingKeys.dailyReminder: true, SettingKeys.dailyReminderAt: 455}),
        now: now,
      );
      final daily = plan.single as DailyReminder;
      expect(daily.id, ReminderIds.daily);
      expect((daily.hour, daily.minute), (7, 35));
    });

    test('the daily reminder is at 20:00 when no time was chosen', () {
      final plan = planReminders(settings: _settings({SettingKeys.dailyReminder: true}), now: now);
      final daily = plan.single as DailyReminder;
      expect((daily.hour, daily.minute), (20, 0));
    });

    test('the weekly summary goes out on the chosen evening with the last 7 days', () {
      final plan = planReminders(
        settings: _settings({
          SettingKeys.weeklySummary: true,
          SettingKeys.weeklySummaryDay: DateTime.friday,
        }),
        now: now,
        weekMoneyOut: 85000,
      );
      final weekly = plan.single as WeeklyReminder;
      expect(weekly.weekday, DateTime.friday);
      expect(weekly.hour, weeklySummaryHour);
      expect(weekly.body, contains('7 days to 19 November'));
      expect(weekly.body, contains('UGX 85,000'));
    });

    test('a regular payment is reminded the morning before, and past ones are skipped', () {
      final plan = planReminders(
        settings: _settings({SettingKeys.regularReminder: true}),
        now: now,
        regular: const [
          // Due today: the morning before has passed.
          DueRegularPayment(label: 'Rent', typicalAmount: 300000, nextDueOn: 20261119),
          // Due tomorrow: the reminder at 09:00 today has passed too.
          DueRegularPayment(label: 'Yaka', typicalAmount: 20000, nextDueOn: 20261120),
          DueRegularPayment(label: 'Data bundle', typicalAmount: 10000, nextDueOn: 20261121),
        ],
      );
      final once = plan.single as OnceReminder;
      expect(once.at, DateTime(2026, 11, 20, regularReminderHour));
      expect(once.title, 'Data bundle is due tomorrow');
      expect(once.body, 'Usually about UGX 10,000.');
      expect(once.id, ReminderIds.regularFirst);
    });

    test('regular payment reminders stop at the cap', () {
      final plan = planReminders(
        settings: _settings({SettingKeys.regularReminder: true}),
        now: now,
        regular: [
          for (var i = 0; i < 30; i++)
            const DueRegularPayment(label: 'Bill', typicalAmount: 1000, nextDueOn: 20261201),
        ],
      );
      expect(plan, hasLength(ReminderIds.regularMax));
      expect(plan.map((r) => r.id).toSet(), hasLength(ReminderIds.regularMax));
    });

    test('a switched-off reminder plans nothing even with figures', () {
      final plan = planReminders(
        settings: _settings({SettingKeys.regularReminder: false, SettingKeys.weeklySummary: false}),
        now: now,
        regular: const [DueRegularPayment(label: 'Rent', typicalAmount: 1, nextDueOn: 20261201)],
        weekMoneyOut: 5,
      );
      expect(plan, isEmpty);
    });
  });

  group('goal reminders', () {
    test('a weekly goal is a repeating Sunday-evening reminder with the amount to put aside', () {
      final plan = planReminders(
        settings: const {},
        now: now,
        goals: const [
          GoalReminderInput(
            name: 'Phone',
            cadence: GoalReminderCadence.weekly,
            periodAmount: 50000,
          ),
        ],
      );
      final weekly = plan.single as WeeklyReminder;
      expect(weekly.id, ReminderIds.goalFirst);
      expect((weekly.weekday, weekly.hour, weekly.minute), (DateTime.sunday, 18, 0));
      expect(weekly.title, 'Set aside for Phone');
      expect(weekly.body, 'Put aside about UGX 50,000 for Phone this week.');
    });

    test('a monthly goal repeats on the 1st at 9 in the morning', () {
      final plan = planReminders(
        settings: const {},
        now: now,
        goals: const [
          GoalReminderInput(
            name: 'School',
            cadence: GoalReminderCadence.monthly,
            periodAmount: 200000,
          ),
        ],
      );
      final monthly = plan.single as MonthlyReminder;
      expect((monthly.day, monthly.hour, monthly.minute), (1, 9, 0));
      expect(monthly.body, 'Put aside about UGX 200,000 for School this month.');
    });

    test('a goal with no date only nudges, with no amount', () {
      final plan = planReminders(
        settings: const {},
        now: now,
        goals: const [GoalReminderInput(name: 'Land', cadence: GoalReminderCadence.weekly)],
      );
      expect((plan.single as WeeklyReminder).body, 'Add to Land this week.');
    });

    test('goals are numbered from goalFirst and no more than goalMax are planned', () {
      final plan = planReminders(
        settings: const {},
        now: now,
        goals: [
          for (var i = 0; i < ReminderIds.goalMax + 5; i++)
            GoalReminderInput(name: 'G$i', cadence: GoalReminderCadence.weekly),
        ],
      );
      expect(plan.length, ReminderIds.goalMax);
      expect(plan.map((r) => r.id), [
        for (var i = 0; i < ReminderIds.goalMax; i++) ReminderIds.goalFirst + i,
      ]);
    });
  });

  group('reminderChanges', () {
    const monthly = MonthlyReminder(
      id: 200,
      title: 'Set aside for Phone',
      body: 'Put aside about UGX 200,000 for Phone this month.',
      day: 1,
      hour: 9,
      minute: 0,
    );
    const daily = DailyReminder(id: 1, title: 't', body: 'b', hour: 8, minute: 0);
    PendingReminder pendingOf(PlannedReminder r, {String? body}) =>
        (id: r.id, title: r.title, body: body ?? r.body, payload: reminderSignature(r));
    // The 1st at 09:05: the 09:00 alarm may still be waiting to go off.
    final justAfter = DateTime(2026, 12, 1, 9, 5);

    test('a reminder already scheduled and unchanged is left alone, even just after its time', () {
      final changes = reminderChanges([monthly], [pendingOf(monthly)], now: justAfter);
      expect(changes.cancel, isEmpty);
      expect(changes.schedule, isEmpty);
    });

    test('just after its time, changed words do not move it: the late alarm is kept', () {
      final changes = reminderChanges(
        [monthly],
        [pendingOf(monthly, body: 'Older amount.')],
        now: justAfter,
      );
      expect(changes.schedule, isEmpty);
    });

    test('well after its time, changed words are scheduled again', () {
      final changes = reminderChanges(
        [monthly],
        [pendingOf(monthly, body: 'Older amount.')],
        now: now,
      );
      expect(changes.schedule, [monthly]);
    });

    test('a new reminder is scheduled', () {
      final changes = reminderChanges([monthly], const [], now: now);
      expect(changes.schedule, [monthly]);
      expect(changes.cancel, isEmpty);
    });

    test('a reminder no longer planned is cancelled, and only that one', () {
      final changes = reminderChanges([monthly], [pendingOf(monthly), pendingOf(daily)], now: now);
      expect(changes.cancel, [1]);
      expect(changes.schedule, isEmpty);
    });

    test('a one-time reminder dropped just after its time is kept until it has gone off', () {
      final rent = OnceReminder(id: 100, title: 'Rent', body: 'b', at: DateTime(2026, 12, 1, 9));
      expect(reminderChanges(const [], [pendingOf(rent)], now: justAfter).cancel, isEmpty);
      expect(reminderChanges(const [], [pendingOf(rent)], now: DateTime(2026, 12, 1, 10)).cancel, [
        100,
      ]);
    });

    test('a repeating reminder switched off just after its time is cancelled', () {
      // Daily 08:00 arrived, and at 08:05 the person switched it off: it must not come again.
      expect(
        reminderChanges(const [], [pendingOf(daily)], now: DateTime(2026, 11, 19, 8, 5)).cancel,
        [1],
      );
      expect(reminderChanges(const [], [pendingOf(monthly)], now: justAfter).cancel, [200]);
    });

    test('a changed time is scheduled again, and so is one set by an older version', () {
      const later = MonthlyReminder(
        id: 200,
        title: 'Set aside for Phone',
        body: 'Put aside about UGX 200,000 for Phone this month.',
        day: 1,
        hour: 10,
        minute: 0,
      );
      expect(reminderChanges([later], [pendingOf(monthly)], now: justAfter).schedule, [later]);
      expect(
        reminderChanges(
          [monthly],
          [(id: 200, title: monthly.title, body: monthly.body, payload: null)],
          now: now,
        ).schedule,
        [monthly],
      );
    });

    test('on the first sync after a start, every planned reminder is scheduled again', () {
      // A restart or force-stop drops the alarms but not the plugin's pending list.
      final changes = reminderChanges(
        [monthly],
        [pendingOf(monthly), pendingOf(daily)],
        now: justAfter,
        trustPending: false,
      );
      expect(changes.schedule, [monthly]);
      expect(changes.cancel, [1]);
    });

    test('each kind has its own signature', () {
      final signatures = {
        reminderSignature(daily),
        reminderSignature(
          const WeeklyReminder(id: 2, title: '', body: '', weekday: 7, hour: 9, minute: 0),
        ),
        reminderSignature(monthly),
        reminderSignature(OnceReminder(id: 100, title: '', body: '', at: DateTime(2026, 12, 1, 9))),
      };
      expect(signatures.length, 4);
    });
  });

  group('lastDueOf', () {
    test('daily: today once its time has come, otherwise yesterday', () {
      expect(lastDueOf('daily:8:0', now), DateTime(2026, 11, 19, 8));
      expect(lastDueOf('daily:20:30', now), DateTime(2026, 11, 18, 20, 30));
    });

    test('weekly: the most recent matching weekday', () {
      // `now` is a Thursday; the last Sunday 18:00 was 15 November.
      expect(lastDueOf('weekly:7:18:0', now), DateTime(2026, 11, 15, 18));
      expect(lastDueOf('weekly:4:9:0', now), DateTime(2026, 11, 19, 9));
    });

    test('monthly: this month once its time has come, otherwise last month, across a year', () {
      expect(lastDueOf('monthly:1:9:0', now), DateTime(2026, 11, 1, 9));
      expect(lastDueOf('monthly:1:9:0', DateTime(2027, 1, 1, 8)), DateTime(2026, 12, 1, 9));
    });

    test('once: its time if it has passed; nothing for one still to come or unknown', () {
      expect(lastDueOf('once:2026-11-19T09:00:00.000', now), DateTime(2026, 11, 19, 9));
      expect(lastDueOf('once:2026-11-20T09:00:00.000', now), isNull);
      expect(lastDueOf(null, now), isNull);
      expect(lastDueOf('yearly:1:1', now), isNull);
      expect(lastDueOf('daily:x:0', now), isNull);
      expect(lastDueOf('daily:8', now), isNull, reason: 'too short: no error, just unknown');
    });
  });

  group('nextMonthlyAt', () {
    test('this month while it is still to come, next month once it has passed', () {
      expect(nextMonthlyAt(DateTime(2026, 11, 1, 8), 1, 9, 0), DateTime(2026, 11, 1, 9));
      expect(nextMonthlyAt(DateTime(2026, 11, 1, 10), 1, 9, 0), DateTime(2026, 12, 1, 9));
    });

    test('December rolls over into January of the next year', () {
      expect(nextMonthlyAt(DateTime(2026, 12, 20), 1, 9, 0), DateTime(2027, 1, 1, 9));
    });
  });

  group('next times', () {
    test('a daily time later today is today, an earlier one is tomorrow', () {
      expect(nextDailyAt(now, 20, 0), DateTime(2026, 11, 19, 20));
      expect(nextDailyAt(now, 10, 15), DateTime(2026, 11, 20, 10, 15));
      expect(nextDailyAt(now, 7, 0), DateTime(2026, 11, 20, 7));
    });

    test('a weekly time finds the next matching weekday', () {
      expect(nextWeeklyAt(now, DateTime.sunday, 19, 0), DateTime(2026, 11, 22, 19));
      expect(nextWeeklyAt(now, DateTime.thursday, 19, 0), DateTime(2026, 11, 19, 19));
      expect(nextWeeklyAt(now, DateTime.thursday, 9, 0), DateTime(2026, 11, 26, 9));
    });

    test('across the end of a month and a year', () {
      expect(nextDailyAt(DateTime(2026, 12, 31, 21), 20, 0), DateTime(2027, 1, 1, 20));
      expect(
        nextWeeklyAt(DateTime(2026, 12, 31, 21), DateTime.sunday, 19, 0),
        DateTime(2027, 1, 3, 19),
      );
    });
  });
}
