import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/period.dart';
import '../../data/db/tables.dart' show GoalRemind;
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/goals.dart';
import '../../domain/spending.dart';
import 'notifications_service.dart';
import 'reminder_plan.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(ReminderScheduler.new);

/// Called once when the app starts, after the first frame is requested. A phone restart or a
/// force-stop drops the scheduled alarms and there is no boot receiver, so this first sync
/// sets every reminder again.
///
/// It also reschedules whenever the regular payments or the savings goals change while the
/// app is open, so a payment or goal that changes never keeps an old reminder. And it
/// reschedules each time the app goes to the background, so the weekly summary carries the
/// figures from the last time Akatabo was open, not from when it started. Both last as long
/// as the app. A failure is reported and never stops the app.
Future<void> rescheduleRemindersAtStart(ProviderContainer container) async {
  final scheduler = container.read(reminderSchedulerProvider);
  final db = container.read(appDatabaseProvider);
  RegularPaymentRepository(db)
      .watchActive()
      .skip(1)
      .listen((_) => _syncReporting(scheduler), onError: (Object _) {});
  // A goal saved, archived, put back or given money changes what its reminder says, or
  // whether it reminds at all.
  final goals = GoalRepository(db);
  goals.watchAll().skip(1).listen((_) => _syncReporting(scheduler), onError: (Object _) {});
  goals.watchAllMoves().skip(1).listen((_) => _syncReporting(scheduler), onError: (Object _) {});
  container.read(_syncWhenHiddenProvider);
  await _syncReporting(scheduler);
}

/// Reschedules each time the app is hidden. Hidden comes before paused on every platform, so
/// one callback covers both. It lasts as long as the container.
final _syncWhenHiddenProvider = Provider<AppLifecycleListener>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final listener = AppLifecycleListener(onHide: () => _syncReporting(scheduler));
  ref.onDispose(listener.dispose);
  return listener;
});

Future<void> _syncReporting(ReminderScheduler scheduler) async {
  try {
    await scheduler.sync();
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo reminders'),
    );
  }
}

/// Brings the scheduled reminders in line with the stored settings.
///
/// Runs when the app starts (there is no boot receiver, so a phone restart drops them),
/// when it goes to the background, and after each change on the Smart help page. Figures in
/// the reminders are read at that moment.
class ReminderScheduler {
  ReminderScheduler(this._ref);
  final Ref _ref;
  Future<void> _last = Future.value();

  /// Reschedules every reminder. Calls run one after another, so two quick changes cannot
  /// interleave their cancel and schedule steps.
  Future<void> sync() => _last = _last.catchError((Object _) {}).then((_) => _run());

  Future<void> _run() async {
    final settings = await _ref.read(settingsRepositoryProvider).watchAll().first;
    bool on(BoolSetting key) => key.decode(settings[key.name]);
    final now = clock.now();

    var regular = const <DueRegularPayment>[];
    if (on(SettingKeys.regularReminder)) {
      final db = _ref.read(appDatabaseProvider);
      final rows = await RegularPaymentRepository(db).watchActive().first;
      regular = [
        for (final r in rows)
          DueRegularPayment(label: r.label, typicalAmount: r.typicalAmount, nextDueOn: r.nextDueOn),
      ];
    }

    var weekOut = 0;
    if (on(SettingKeys.weeklySummary)) {
      final today = dateOnly(now);
      final week = Period(addDays(today, -6), addDays(today, 1), PeriodKind.custom);
      weekOut = totalsOf(await _ref.read(transactionRepositoryProvider).watchIn(week).first)
          .moneyOut;
    }

    final goals = await _goalReminders(now);

    await _ref
        .read(notificationsServiceProvider)
        .replaceAll(
          planReminders(
            settings: settings,
            now: now,
            regular: regular,
            weekMoneyOut: weekOut,
            goals: goals,
          ),
        );
  }

  /// The goals that ask to be reminded and still have money to reach, each with what to set
  /// aside in its next week or month. Reached goals and goals set to "Off" are left out.
  Future<List<GoalReminderInput>> _goalReminders(DateTime now) async {
    final db = _ref.read(appDatabaseProvider);
    final active = await GoalRepository(db).watchActive().first;
    final moves = await GoalRepository(db).watchAllMoves().first;
    final today = dateOnly(now);
    final out = <GoalReminderInput>[];
    for (final goal in active) {
      final cadence = switch (goal.remindEvery) {
        GoalRemind.off => null,
        GoalRemind.weekly => GoalReminderCadence.weekly,
        GoalRemind.monthly => GoalReminderCadence.monthly,
      };
      if (cadence == null) continue;
      final saved = savedOf([
        for (final m in moves)
          if (m.goalId == goal.id) GoalMoveEntry(amount: m.amount, localDay: m.localDay),
      ]);
      if (saved >= goal.target) continue;
      final weekly = cadence == GoalReminderCadence.weekly;
      out.add(
        GoalReminderInput(
          name: goal.name,
          cadence: cadence,
          periodAmount: requiredPer(
            target: goal.target,
            saved: saved,
            targetDay: goal.targetDay,
            today: today,
            periodDays: weekly ? 7 : 30,
          ),
        ),
      );
    }
    return out;
  }
}
