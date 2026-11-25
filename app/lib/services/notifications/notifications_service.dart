import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// Shows reminders at a local time. Screens and the start-up code use this interface, so
/// tests replace it with a fake and never reach the plugin.
abstract interface class NotificationsService {
  /// Asks the phone to allow notifications. True when they are allowed.
  Future<bool> requestPermission();

  /// Whether notifications are allowed now, without asking. The person can turn them off in
  /// the phone's settings after switching a reminder on.
  Future<bool> areAllowed();

  /// Makes the scheduled reminders exactly [reminders]: any no longer planned are cancelled,
  /// any unchanged are left alone (so one still waiting on a delayed alarm is not lost), and
  /// the rest are scheduled. Notifications already shown, such as a budget warning, stay.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Shows a notification now. A later one with the same [id] replaces it.
  Future<void> showNow(int id, String title, String body);
}

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => LocalNotificationsService(),
);

/// [NotificationsService] on `flutter_local_notifications`.
///
/// Scheduling is inexact (`inexactAllowWhileIdle`): no exact-alarm permission, so a reminder
/// can arrive a few minutes late. There is no boot receiver either: the first sync after the
/// app starts schedules every reminder again, because a phone restart or a force-stop drops
/// the alarms while the plugin's list of pending reminders survives.
class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Whether every reminder has been scheduled since the app started. Until then the plugin's
  /// pending list may describe alarms that no longer exist.
  bool _scheduledThisRun = false;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  /// Kampala when the phone's own zone cannot be read: the app is made for Uganda.
  static const fallbackZone = 'Africa/Kampala';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Daily nudge, regular payments, savings goals and the weekly summary',
      largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _budgetDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'budgets',
      'Budget warnings',
      channelDescription: 'When a budget is nearly used, and when it goes over',
      largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      tz.setLocalLocation(tz.getLocation(fallbackZone));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_akatabo'),
        // Never ask at start-up: permission is asked only when a reminder is switched on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false,
      TargetPlatform.iOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, sound: true) ??
            false,
      _ => false,
    };
  }

  @override
  Future<bool> areAllowed() async {
    await _init();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false,
      TargetPlatform.iOS =>
        (await _plugin
                    .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                    ?.checkPermissions())
                ?.isEnabled ??
            false,
      _ => false,
    };
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _init();
    // Only the scheduled ones are touched: cancelling everything would also clear a budget
    // warning already shown, and would lose an alarm that is late but has not gone off.
    final pending = await _plugin.pendingNotificationRequests();
    final now = DateTime.now();
    final changes = reminderChanges(
      reminders,
      [for (final p in pending) (id: p.id, title: p.title, body: p.body, payload: p.payload)],
      now: now,
      trustPending: _scheduledThisRun,
    );
    for (final id in changes.cancel) {
      await _plugin.cancel(id: id);
    }
    for (final r in changes.schedule) {
      final (DateTime at, DateTimeComponents? repeat) = switch (r) {
        DailyReminder(:final hour, :final minute) => (
          nextDailyAt(now, hour, minute),
          DateTimeComponents.time,
        ),
        WeeklyReminder(:final weekday, :final hour, :final minute) => (
          nextWeeklyAt(now, weekday, hour, minute),
          DateTimeComponents.dayOfWeekAndTime,
        ),
        MonthlyReminder(:final day, :final hour, :final minute) => (
          nextMonthlyAt(now, day, hour, minute),
          DateTimeComponents.dayOfMonthAndTime,
        ),
        OnceReminder(:final at) => (at, null),
      };
      if (!at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: repeat,
        payload: reminderSignature(r),
      );
    }
    // Only once both steps worked: a failure part-way leaves the next sync to set them all.
    _scheduledThisRun = true;
  }

  @override
  Future<void> showNow(int id, String title, String body) async {
    await _init();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: _budgetDetails);
  }
}
