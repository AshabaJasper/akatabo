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
    // A payment's id is its place among those whose reminder is still to come or came in the
    // last [lateAlarmGrace]. One that is just due keeps its place, so the later payments' ids
    // do not slide onto the id of a reminder that may still be waiting to go off. Payments
    // whose reminder is long past take no place, so they never use up the ids.
    final live = [
      for (final p in regular)
        if (regularReminderAt(p.nextDueOn).isAfter(now.subtract(lateAlarmGrace))) p,
    ];
    for (var n = 0; n < live.length && n < ReminderIds.regularMax; n++) {
      final p = live[n];
      final at = regularReminderAt(p.nextDueOn);
      if (!at.isAfter(now)) continue;
      plan.add(
        OnceReminder(
          id: ReminderIds.regularFirst + n,
          title: '${p.label} is due tomorrow',
          body: 'Usually about ${formatUgx(p.typicalAmount)}.',
          at: at,
        ),
      );
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

/// A reminder the phone already has scheduled, as far as the comparison needs it.
typedef PendingReminder = ({int id, String? title, String? body, String? payload});

/// What a reminder is and when it repeats, kept with the scheduled notification so a later
/// sync can tell that it is unchanged.
String reminderSignature(PlannedReminder r) => switch (r) {
  DailyReminder(:final hour, :final minute) => 'daily:$hour:$minute',
  WeeklyReminder(:final weekday, :final hour, :final minute) => 'weekly:$weekday:$hour:$minute',
  MonthlyReminder(:final day, :final hour, :final minute) => 'monthly:$day:$hour:$minute',
  OnceReminder(:final at) => 'once:${at.toIso8601String()}',
};

/// What to do to bring the phone's scheduled reminders in line with the plan.
class ReminderChanges {
  const ReminderChanges({required this.cancel, required this.schedule});

  /// Ids scheduled on the phone that the plan no longer has.
  final List<int> cancel;

  /// Reminders that are new, or whose words or schedule changed.
  final List<PlannedReminder> schedule;
}

/// How long after its time a scheduled reminder is still treated as waiting to go off.
/// Scheduling is inexact, so an alarm can come a few minutes late.
const lateAlarmGrace = Duration(minutes: 30);

/// The most recent time, at or before [now], that the reminder with this [payload] signature
/// was due. Null for a signature this version does not know, such as one set by an older
/// version, or a one-time reminder still to come.
DateTime? lastDueOf(String? payload, DateTime now) {
  final parts = payload?.split(':');
  if (parts == null || parts.length < 2) return null;
  int n(int i) => int.parse(parts[i]);
  try {
    switch (parts.first) {
      case 'daily':
        final today = DateTime(now.year, now.month, now.day, n(1), n(2));
        return today.isAfter(now) ? DateTime(now.year, now.month, now.day - 1, n(1), n(2)) : today;
      case 'weekly':
        var at = DateTime(now.year, now.month, now.day, n(2), n(3));
        for (var i = 0; i < 8 && (at.weekday != n(1) || at.isAfter(now)); i++) {
          at = DateTime(at.year, at.month, at.day - 1, n(2), n(3));
        }
        return at;
      case 'monthly':
        final thisMonth = DateTime(now.year, now.month, n(1), n(2), n(3));
        return thisMonth.isAfter(now)
            ? DateTime(now.year, now.month - 1, n(1), n(2), n(3))
            : thisMonth;
      case 'once':
        final at = DateTime.parse(payload!.substring('once:'.length));
        return at.isAfter(now) ? null : at;
    }
  } on Object {
    // A payload this version did not write, such as a short or garbled one.
    return null;
  }
  return null;
}

/// Whether [p]'s reminder came due within [lateAlarmGrace] before [now], so its alarm may
/// still be on its way.
bool isJustDue(PendingReminder p, DateTime now) {
  final last = lastDueOf(p.payload, now);
  if (last == null) return false;
  final since = now.difference(last);
  return !since.isNegative && since <= lateAlarmGrace;
}

/// The just-due one-time reminders whose alarm may have been lost when the app started.
/// Used on the first sync after a start, which sets every reminder again.
///
/// Only one-time reminders count. Android takes a one-time reminder off its pending list when
/// it goes off, so one still listed and just due has not been shown. A repeating reminder
/// stays listed after it goes off, so "lost" cannot be told from "already shown", and showing
/// it would often repeat one the person has read. A reminder on screen ([shownIds]) is skipped
/// too. The caller must not call this when the app was opened by tapping a notification.
List<PendingReminder> missedLateAlarms(
  List<PendingReminder> pending, {
  required DateTime now,
  required Set<int> shownIds,
}) => [
  for (final p in pending)
    if ((p.payload?.startsWith('once:') ?? false) && !shownIds.contains(p.id) && isJustDue(p, now))
      p,
];

/// Compares the plan with what the phone has scheduled.
///
/// A reminder that is unchanged is left alone. So is one whose time came within
/// [lateAlarmGrace] before [now] and whose words changed since, and a one-time reminder the
/// plan dropped because its time has passed:
/// cancelling or setting it again then would lose an inexact alarm that is late but has not
/// gone off, and push that reminder a whole day, week or month away. It is brought up to date
/// on a later sync, once its time is well past. A repeating reminder the plan dropped was
/// switched off, so it is cancelled at once; kept, it would go off again a period later.
///
/// [trustPending] is false on the first sync after the app starts. Android forgets every
/// alarm when the phone restarts or the app is force-stopped, but the plugin's list of
/// pending reminders survives, so that list cannot be taken to mean the alarms exist: every
/// planned reminder is scheduled again, which also takes up a new time zone.
ReminderChanges reminderChanges(
  List<PlannedReminder> planned,
  List<PendingReminder> pending, {
  required DateTime now,
  bool trustPending = true,
}) {
  final plannedIds = {for (final r in planned) r.id};
  final pendingById = {for (final p in pending) p.id: p};
  bool justDue(PendingReminder p) => isJustDue(p, now);

  bool lateOnce(PendingReminder p) => (p.payload?.startsWith('once:') ?? false) && justDue(p);

  bool keep(PlannedReminder r) {
    if (!trustPending) return false;
    final p = pendingById[r.id];
    if (p == null || p.payload != reminderSignature(r)) return false;
    // Within the window only the words may differ: a different title is a different thing
    // that has taken over the id, and its own reminder must be set.
    return p.title == r.title && (p.body == r.body || justDue(p));
  }

  return ReminderChanges(
    cancel: [
      for (final p in pending)
        if (!plannedIds.contains(p.id) && !(trustPending && lateOnce(p))) p.id,
    ],
    schedule: [
      for (final r in planned)
        if (!keep(r)) r,
    ],
  );
}

/// When a regular payment due on [dueOn] (yyyymmdd) is reminded of: the morning before.
DateTime regularReminderAt(int dueOn) {
  final dayBefore = addDays(fromLocalDay(dueOn), -1);
  return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, regularReminderHour);
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
