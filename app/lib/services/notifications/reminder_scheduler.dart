import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/period.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/spending.dart';
import 'notifications_service.dart';
import 'reminder_plan.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>(ReminderScheduler.new);

/// Called once when the app starts, after the first frame is requested. A phone restart
/// clears scheduled notifications and there is no boot receiver, so they are set again here.
///
/// It also reschedules whenever the regular payments change while the app is open, so a
/// payment that is added, moved on or dismissed never keeps an old reminder. The
/// subscription lasts as long as the app. A failure is reported and never stops the app.
Future<void> rescheduleRemindersAtStart(ProviderContainer container) async {
  final scheduler = container.read(reminderSchedulerProvider);
  RegularPaymentRepository(container.read(appDatabaseProvider))
      .watchActive()
      .skip(1)
      .listen((_) => _syncReporting(scheduler), onError: (Object _) {});
  await _syncReporting(scheduler);
}

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
/// Runs when the app starts (there is no boot receiver, so a phone restart clears them) and
/// after each change on the Smart help page. Figures in the reminders are read at that moment.
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

    await _ref
        .read(notificationsServiceProvider)
        .replaceAll(
          planReminders(settings: settings, now: now, regular: regular, weekMoneyOut: weekOut),
        );
  }
}
