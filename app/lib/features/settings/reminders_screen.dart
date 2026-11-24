import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/notifications/notifications_service.dart';
import '../../services/notifications/reminder_plan.dart' show weeklySummaryHour;
import '../../services/notifications/reminder_scheduler.dart';
import '../../services/notifications/reminder_switch.dart' show notificationsRefusedMessage;
import '../../services/permissions/phone_permissions.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_pickers.dart';
import 'permissions_screen.dart' show settingsNotOpenedMessage;
import 'settings_page.dart';
import 'smart_rows.dart';

/// The next moment a reminder at [hour]:[minute] fires, after [now]: today if that time is still
/// to come, otherwise the next day. With a [weekday], the next day that matches it.
DateTime nextReminderAt(DateTime now, {required int hour, required int minute, int? weekday}) {
  var at = DateTime(now.year, now.month, now.day, hour, minute);
  for (var i = 0; i < 8 && ((weekday != null && at.weekday != weekday) || !at.isAfter(now)); i++) {
    at = DateTime(at.year, at.month, at.day + 1, hour, minute);
  }
  return at;
}

/// "tonight, 20:00", "tomorrow, 07:30", "Sunday, 19:00" or, a week ahead, "next Sunday,
/// 19:00": when a reminder next fires, in words a person would say.
String nextReminderWords(DateTime next, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(next.year, next.month, next.day);
  // Rounded: a day is 23 or 25 hours where the clocks change.
  final gap = (day.difference(today).inHours / 24).round();
  final name = weekdayNames[next.weekday - 1];
  final when = switch (gap) {
    0 => next.hour >= 18 ? 'tonight' : 'today',
    1 => 'tomorrow',
    // Today's name would read as today, which has already passed.
    >= 7 => 'next $name',
    _ => name,
  };
  return '$when, ${clockText(next.hour * 60 + next.minute)}';
}

/// Reminders on their own page: each switch, its next time, the time and day, and whether the
/// phone allows notifications. A test notification checks the whole path.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

/// Shown when a reminder is on but the phone no longer allows notifications.
const notificationsBlockedMessage =
    "Notifications are off for Akatabo in your phone's settings, so reminders cannot "
    'arrive. Allow them there for Akatabo.';

/// The id of the test notification. The reminders use ids 1, 2 and 100 and up.
const _testNotificationId = 99;

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  String? _problem;
  String? _done;
  bool _asking = false;

  /// Whether the phone allows notifications. Null until known. Read when the page opens and
  /// again each time Akatabo comes back, since the blocked note sends the person to the phone's
  /// settings to change it.
  bool? _allowed;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _checkAllowed);
    _checkAllowed();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _checkAllowed() async {
    bool allowed;
    try {
      allowed = await ref.read(notificationsServiceProvider).areAllowed();
    } on Object {
      return;
    }
    if (mounted) setState(() => _allowed = allowed);
  }

  /// Saves one setting. [reschedule] for reminder settings, so the notifications follow.
  Future<void> _save<T>(SettingKey<T> key, T value, {bool reschedule = false}) async {
    setState(() {
      _problem = null;
      _done = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
      return;
    }
    if (!reschedule) return;
    try {
      await ref.read(reminderSchedulerProvider).sync();
    } on Object {
      if (mounted) {
        setState(
          () => _problem =
              'Saved, but the reminders could not be set. They are set again when '
              'Akatabo next opens.',
        );
      }
    }
  }

  /// A reminder switch. Switching on asks for permission first; a refusal leaves it off.
  Future<void> _switchReminder(BoolSetting key, bool on) async {
    if (!on) return _save(key, false, reschedule: true);
    if (_asking) return;
    setState(() {
      _asking = true;
      _problem = null;
      _done = null;
    });
    var allowed = false;
    try {
      allowed = await ref.read(notificationsServiceProvider).requestPermission();
    } on Object {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _asking = false;
      _allowed = allowed;
    });
    if (!allowed) {
      setState(() => _problem = notificationsRefusedMessage);
      return;
    }
    await _save(key, true, reschedule: true);
  }

  Future<void> _pickTime(int minutes) async {
    final picked = await showAkTimePicker(
      context,
      initial: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Remind me at',
    );
    if (picked == null) return;
    await _save(SettingKeys.dailyReminderAt, picked.hour * 60 + picked.minute, reschedule: true);
  }

  Future<void> _pickDay(int current) async {
    final picked = await showAkChoiceSheet<int>(
      context,
      title: 'Send the weekly summary on',
      options: [for (var d = DateTime.monday; d <= DateTime.sunday; d++) (d, eveningText(d))],
      selected: current,
    );
    if (picked != null) await _save(SettingKeys.weeklySummaryDay, picked, reschedule: true);
  }

  /// Opens Akatabo's notification settings in the phone, where a block is lifted.
  Future<void> _openSettings() async {
    setState(() {
      _problem = null;
      _done = null;
    });
    final opened = await ref.read(phonePermissionsProvider).open(PhoneSettingsPage.notifications);
    if (!opened && mounted) setState(() => _problem = settingsNotOpenedMessage);
  }

  /// Sends one notification now, so the person can see that reminders reach this phone.
  Future<void> _sendTest() async {
    setState(() {
      _problem = null;
      _done = null;
    });
    try {
      final service = ref.read(notificationsServiceProvider);
      final allowed = await service.areAllowed();
      if (mounted) setState(() => _allowed = allowed);
      if (!allowed) {
        if (mounted) setState(() => _problem = notificationsBlockedMessage);
        return;
      }
      await service.showNow(
        _testNotificationId,
        'Akatabo',
        'Reminders can reach you on this phone.',
      );
      if (mounted) setState(() => _done = 'Sent. It should appear at the top of your phone.');
    } on Object {
      if (mounted) setState(() => _problem = 'The test could not be sent. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final async = ref.watch(storedSettingsProvider);
    const title = 'Reminders';
    if (async.hasError) {
      return const SettingsPage(
        title: title,
        children: [AkEmptyNote('Settings could not load. Close Akatabo and open it again.')],
      );
    }
    if (!async.hasValue) return const SettingsPage(title: title, children: []);

    final s = async.requireValue;
    T read<T>(SettingKey<T> key) => readSetting(s, key);
    final at = read(SettingKeys.dailyReminderAt);
    final day = read(SettingKeys.weeklySummaryDay);
    final now = clock.now();
    final daily = read(SettingKeys.dailyReminder);
    final weekly = read(SettingKeys.weeklySummary);

    String nextDaily() =>
        'Next: ${nextReminderWords(nextReminderAt(now, hour: at ~/ 60, minute: at % 60), now)}';
    String nextWeekly() =>
        'Next: ${nextReminderWords(nextReminderAt(now, hour: weeklySummaryHour, minute: 0, weekday: day), now)}';

    return SettingsPage(
      title: title,
      children: [
        Text(
          'A reminder is sent only when you switch it on. Each one shows when it next fires.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'Reminders',
          children: [
            NotedSwitchRow(
              label: 'Remind me to add each day',
              note: daily ? nextDaily() : 'Off',
              value: daily,
              onChanged: (v) => _switchReminder(SettingKeys.dailyReminder, v),
            ),
            SettingsValueRow(
              title: 'At',
              value: clockText(at),
              onTap: () => _pickTime(at),
              divider: true,
            ),
            // One source of truth: each budget keeps its own warn level (Set a budget), and
            // this switch only says whether a notification is sent when it is reached.
            NotedSwitchRow(
              label: 'Warn me when a budget is nearly used',
              note: "At each budget's own warn level, and again if it goes over",
              value: read(SettingKeys.budgetWarn),
              onChanged: (v) => _switchReminder(SettingKeys.budgetWarn, v),
            ),
            NotedSwitchRow(
              label: 'Tell me before a regular payment',
              note: 'The morning before it is due',
              value: read(SettingKeys.regularReminder),
              onChanged: (v) => _switchReminder(SettingKeys.regularReminder, v),
            ),
            NotedSwitchRow(
              label: 'Weekly summary',
              note: weekly ? nextWeekly() : 'Off',
              value: weekly,
              onChanged: (v) => _switchReminder(SettingKeys.weeklySummary, v),
            ),
            SettingsValueRow(title: 'Sent on', value: eveningText(day), onTap: () => _pickDay(day)),
          ],
        ),
        SettingsSection(
          label: 'Check',
          children: [
            SettingsValueRow(
              title: 'Notifications on this phone',
              value: _allowed == null
                  ? 'Checking'
                  : _allowed!
                  ? 'Allowed'
                  : 'Blocked',
              divider: true,
            ),
            ActionRow(
              label: 'Send a test notification',
              onTap: _sendTest,
              destructive: false,
              divider: true,
            ),
            ActionRow(
              label: 'Open notification settings',
              onTap: _openSettings,
              destructive: false,
            ),
          ],
        ),
        if (_allowed == false &&
            _problem == null &&
            (daily || read(SettingKeys.budgetWarn) || read(SettingKeys.regularReminder) || weekly))
          const AkEmptyNote(notificationsBlockedMessage),
        if (_problem != null) AkEmptyNote(_problem!),
        if (_done != null) AkEmptyNote(_done!),
      ],
    );
  }
}
