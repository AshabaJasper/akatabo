import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import 'notifications_service.dart';
import 'reminder_scheduler.dart';

/// Shown when the phone refuses notifications, so the switch stays off.
const notificationsRefusedMessage =
    'Notifications are off for Akatabo, so this reminder stays off. Allow them in your '
    "phone's settings for Akatabo, then switch it on again.";

/// Switches a reminder on or off from any page. On asks the phone for permission first, and
/// a refusal leaves it off. Then the reminders are set again. Returns null when all went
/// well, or the sentence to show.
Future<String?> switchReminder(WidgetRef ref, BoolSetting key, {required bool on}) async {
  if (on) {
    var allowed = false;
    try {
      allowed = await ref.read(notificationsServiceProvider).requestPermission();
    } on Object {
      allowed = false;
    }
    if (!allowed) return notificationsRefusedMessage;
  }
  try {
    await ref.read(settingsRepositoryProvider).write(key, on);
  } on Object {
    return 'That could not be saved. Try again.';
  }
  try {
    await ref.read(reminderSchedulerProvider).sync();
  } on Object {
    return 'Saved, but the reminders could not be set. They are set again when Akatabo '
        'next opens.';
  }
  return null;
}
