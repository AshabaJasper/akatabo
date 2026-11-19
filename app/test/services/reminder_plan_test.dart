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
