/// Which reminders to schedule, worked out from the stored settings and the figures read when
/// the app was last open. Pure Dart: no Flutter and no plugin, so every rule is unit tested.
library;

import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/time/period.dart';
import '../../data/settings/setting_keys.dart';

/// One notification to schedule. Times are local wall-clock times.
sealed class PlannedReminder {
  const PlannedReminder({required this.id, required this.title, required this.body});
  final int id;
  final String title;
  final String body;
}

/// Every day at [hour]:[minute].
final class DailyReminder extends PlannedReminder {
  const DailyReminder({
    required super.id,
    required super.title,
    required super.body,
    required this.hour,
    required this.minute,
  });
  final int hour;
  final int minute;
}

/// Every week on [weekday] ([DateTime.monday] to [DateTime.sunday]) at [hour]:[minute].
final class WeeklyReminder extends PlannedReminder {
  const WeeklyReminder({
    required super.id,
    required super.title,
    required super.body,
    required this.weekday,
    required this.hour,
    required this.minute,
  });
  final int weekday;
  final int hour;
  final int minute;
}

/// Every month on [day] at [hour]:[minute].
final class MonthlyReminder extends PlannedReminder {
  const MonthlyReminder({
    required super.id,
    required super.title,
    required super.body,
    required this.day,
    required this.hour,
    required this.minute,
  });
  final int day;
  final int hour;
  final int minute;
}

/// Once, at [at].
final class OnceReminder extends PlannedReminder {
  const OnceReminder({
    required super.id,
    required super.title,
    required super.body,
    required this.at,
  });
  final DateTime at;
}

/// A regular payment as the reminder needs it.
class DueRegularPayment {
  const DueRegularPayment({
    required this.label,
    required this.typicalAmount,
    required this.nextDueOn,
  });
  final String label;
  final int typicalAmount;

  /// yyyymmdd.
  final int nextDueOn;
}

/// Notification ids. Regular payments use [regularFirst] upwards, at most [regularMax] of them.
abstract final class ReminderIds {
  static const daily = 1;
  static const weekly = 2;
  static const regularFirst = 100;
  static const regularMax = 20;
  static const goalFirst = 200;
  static const goalMax = 20;
}

/// How often a goal asks for money to be set aside. Mirrors the goal's "Remind me" choice.
enum GoalReminderCadence { weekly, monthly }

/// A goal that asks to be reminded, with what to set aside in its next period. [weeklyAmount]
/// or [monthlyAmount] is null when the goal has no date, so the reminder only nudges.
class GoalReminderInput {
  const GoalReminderInput({required this.name, required this.cadence, this.periodAmount});
  final String name;
  final GoalReminderCadence cadence;

  /// Whole shillings for one week or one month, as [cadence] says. Null with no date.
  final int? periodAmount;
}

/// The weekly summary goes out in the evening, at this hour.
const weeklySummaryHour = 19;

/// A regular payment's reminder goes out the morning before it is due, at this hour.
const regularReminderHour = 9;

/// Goal reminders: weekly on Sunday evening, monthly on the 1st in the morning.
const goalWeeklyWeekday = DateTime.sunday;
const goalWeeklyHour = 18;
const goalMonthlyDay = 1;
const goalMonthlyHour = regularReminderHour;

/// The reminders the settings ask for.
///
/// [weekMoneyOut] is money out in the seven days up to and including [now]'s day; it is only
/// read when the weekly summary is on. [regular] is only read when the regular payment
/// reminder is on.
List<PlannedReminder> planReminders({
  required Map<String, String> settings,
  required DateTime now,
  List<DueRegularPayment> regular = const [],
  int weekMoneyOut = 0,
  List<GoalReminderInput> goals = const [],
}) {
  bool on(BoolSetting key) => key.decode(settings[key.name]);
  final plan = <PlannedReminder>[];

  if (on(SettingKeys.dailyReminder)) {
    final at = SettingKeys.dailyReminderAt.decode(settings[SettingKeys.dailyReminderAt.name]);
    plan.add(
      DailyReminder(
        id: ReminderIds.daily,
        title: 'Add today in Akatabo',
        body: 'Add what you spent and received today, while you remember it.',
        hour: at ~/ 60,
        minute: at % 60,
      ),
    );
  }

  if (on(SettingKeys.weeklySummary)) {
    final day = SettingKeys.weeklySummaryDay.decode(settings[SettingKeys.weeklySummaryDay.name]);
    final upTo = DateFormat('d MMMM').format(now);
    plan.add(
      WeeklyReminder(
        id: ReminderIds.weekly,
        title: 'Your week in Akatabo',
        body:
            'Money out in the 7 days to $upTo: ${formatUgx(weekMoneyOut)}. '
            'Open Akatabo for the latest figures.',
        weekday: day,
        hour: weeklySummaryHour,
        minute: 0,
      ),
    );
  }

  if (on(SettingKeys.regularReminder)) {
    var n = 0;
    for (final p in regular) {
      if (n >= ReminderIds.regularMax) break;
      final due = fromLocalDay(p.nextDueOn);
      final dayBefore = addDays(due, -1);
      final at = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, regularReminderHour);
      if (!at.isAfter(now)) continue;
      plan.add(
        OnceReminder(
          id: ReminderIds.regularFirst + n,
          title: '${p.label} is due tomorrow',
          body: 'Usually about ${formatUgx(p.typicalAmount)}.',
          at: at,
        ),
      );
      n++;
    }
  }

  var g = 0;
  for (final goal in goals) {
    if (g >= ReminderIds.goalMax) break;
    final id = ReminderIds.goalFirst + g;
    final weekly = goal.cadence == GoalReminderCadence.weekly;
    final amount = goal.periodAmount;
    final period = weekly ? 'this week' : 'this month';
    final body = amount == null
        ? 'Add to ${goal.name} $period.'
        : 'Put aside about ${formatUgx(amount)} for ${goal.name} $period.';
    plan.add(
      weekly
          ? WeeklyReminder(
              id: id,
              title: 'Set aside for ${goal.name}',
              body: body,
              weekday: goalWeeklyWeekday,
              hour: goalWeeklyHour,
              minute: 0,
            )
          : MonthlyReminder(
              id: id,
              title: 'Set aside for ${goal.name}',
              body: body,
              day: goalMonthlyDay,
              hour: goalMonthlyHour,
              minute: 0,
            ),
    );
    g++;
  }

  return plan;
}

/// The next time after [now] that falls on [day] of a month at [hour]:[minute]. If that moment
/// this month has not yet come, it is this month's; otherwise next month's.
DateTime nextMonthlyAt(DateTime now, int day, int hour, int minute) {
  final thisMonth = DateTime(now.year, now.month, day, hour, minute);
  return thisMonth.isAfter(now) ? thisMonth : DateTime(now.year, now.month + 1, day, hour, minute);
}

/// The next time after [now] that reads [hour]:[minute] on the clock.
DateTime nextDailyAt(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, hour, minute);
}

/// The next time after [now] that falls on [weekday] at [hour]:[minute].
DateTime nextWeeklyAt(DateTime now, int weekday, int hour, int minute) {
  var at = DateTime(now.year, now.month, now.day, hour, minute);
  for (var i = 0; i < 8 && (at.weekday != weekday || !at.isAfter(now)); i++) {
    at = DateTime(at.year, at.month, at.day + 1, hour, minute);
  }
  return at;
}
