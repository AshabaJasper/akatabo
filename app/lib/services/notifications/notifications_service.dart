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

  /// Cancels every scheduled reminder, then schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => LocalNotificationsService(),
);

/// [NotificationsService] on `flutter_local_notifications`.
///
/// Scheduling is inexact (`inexactAllowWhileIdle`): no exact-alarm permission, so a reminder
/// can arrive a few minutes late. There is no boot receiver either; the app reschedules every
/// reminder each time it starts.
class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  /// Kampala when the phone's own zone cannot be read: the app is made for Uganda.
  static const fallbackZone = 'Africa/Kampala';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Daily nudge, regular payments and the weekly summary',
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
    await _plugin.cancelAll();
    final now = DateTime.now();
    for (final r in reminders) {
      final (DateTime at, DateTimeComponents? repeat) = switch (r) {
        DailyReminder(:final hour, :final minute) => (
          nextDailyAt(now, hour, minute),
          DateTimeComponents.time,
        ),
        WeeklyReminder(:final weekday, :final hour, :final minute) => (
          nextWeeklyAt(now, weekday, hour, minute),
          DateTimeComponents.dayOfWeekAndTime,
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
      );
    }
  }
}
