import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/forecast.dart' show monthlyIntervalDays;
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:akatabo/services/notifications/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  group('upcomingRegular', () {
    test('a payment whose start date is months back is reminded of its next due date', () {
      // Monthly from 5 June: the next one after 25 November is 5 December.
      final rows = [
        regularRow(label: 'Rent', nextDueOn: 20260605, intervalDays: monthlyIntervalDays),
      ];
      final due = upcomingRegular(rows, DateTime(2026, 11, 25, 10));
      expect(due.single.nextDueOn, 20261205);
    });

    test('one due tomorrow whose reminder came minutes ago keeps that date', () {
      // Due 26 November: its reminder was 25 November at 09:00, ten minutes ago.
      final rows = [regularRow(nextDueOn: 20261126)];
      expect(upcomingRegular(rows, DateTime(2026, 11, 25, 9, 10)).first.nextDueOn, 20261126);
    });

    test('just after its reminder, the next date is listed too and is the one scheduled', () {
      // A weekly payment due Thursday 26 November: its reminder came at 09:00, five minutes ago.
      final rows = [regularRow(nextDueOn: 20261126)];
      final now = DateTime(2026, 11, 25, 9, 5);
      final due = upcomingRegular(rows, now);
      expect(due.map((d) => d.nextDueOn), [20261126, 20261203]);
      final plan = planReminders(
        settings: {SettingKeys.regularReminder.name: '1'},
        now: now,
        regular: due,
      );
      // The just-due date keeps id 100 for its late alarm; the next one is set on 101.
      final once = plan.single as OnceReminder;
      expect(once.id, ReminderIds.regularFirst + 1);
      expect(once.at, DateTime(2026, 12, 2, regularReminderHour));
    });

    test('a payment every 5 days that started years ago still has its next date', () {
      // 7 September 2018 is 3,001 days before 25 November 2026, past the 400-step limit.
      final rows = [regularRow(nextDueOn: 20180907, intervalDays: 5)];
      final due = upcomingRegular(rows, DateTime(2026, 11, 25, 10));
      expect(due.single.nextDueOn, 20261129);
    });

    test('once its reminder is well past, the next period is used', () {
      final rows = [regularRow(nextDueOn: 20261126)];
      expect(upcomingRegular(rows, DateTime(2026, 11, 25, 11)).single.nextDueOn, 20261203);
    });

    test('the list is in due order, not in the order of the start dates', () {
      final rows = [
        regularRow(id: 'a', label: 'Rent', nextDueOn: 20260601, intervalDays: monthlyIntervalDays),
        regularRow(id: 'b', label: 'Water', nextDueOn: 20261128, intervalDays: 30),
      ];
      final due = upcomingRegular(rows, DateTime(2026, 11, 25, 10));
      expect(due.map((d) => d.label), ['Water', 'Rent']);
    });

    test('a dismissed payment is left out', () {
      final rows = [regularRow(nextDueOn: 20261130, dismissed: true)];
      expect(upcomingRegular(rows, DateTime(2026, 11, 25, 10)), isEmpty);
    });
  });
}
