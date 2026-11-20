import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/notifications/notifications_service.dart';
import '../../services/notifications/reminder_scheduler.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_pickers.dart';
import 'settings_page.dart';

/// Smart help and Reminders on one page, as drawn. Both hub rows open it.
///
/// "Forecast the month" hides the forecast; the other Smart help switches only store their
/// choice until the models arrive, and a note says so. Reminder switches ask
/// for notification permission when they are switched on, and every reminder change
/// reschedules the notifications.
class SmartSettingsScreen extends ConsumerStatefulWidget {
  const SmartSettingsScreen({super.key, this.openAtReminders = false});

  /// Scrolls to the Reminders section once the settings load: the hub's Reminders row.
  final bool openAtReminders;

  @override
  ConsumerState<SmartSettingsScreen> createState() => _SmartSettingsScreenState();
}

/// Shown when the phone refuses notifications, so the switch stays off.
const notificationsRefusedMessage =
    'Notifications are off for Akatabo, so this reminder stays off. Allow them in your '
    "phone's settings for Akatabo, then switch it on again.";

/// Shown when a reminder is on but the phone no longer allows notifications.
const notificationsBlockedMessage =
    "Notifications are off for Akatabo in your phone's settings, so reminders cannot "
    'arrive. Allow them there for Akatabo.';

/// Under the Smart help switches whose models arrive in a later phase. Their choices are
/// stored now and take effect then.
const laterNote =
    'Suggesting a category, pointing out unusual payments and noticing regular payments '
    'start working when Smart help arrives in a later update. Your choices here are kept '
    'until then.';

const forgotMessage = 'Smart help has forgotten what it learned. Your entries are unchanged.';

class _SmartSettingsScreenState extends ConsumerState<SmartSettingsScreen> {
  static const _title = 'Smart help';

  String? _problem;
  String? _done;
  bool _asking = false;
  final _remindersKey = GlobalKey();
  late bool _scrollPending = widget.openAtReminders;

  /// Whether the phone allows notifications, read once when the page opens. Null until known.
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _checkAllowed();
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

  void _scrollToReminders() {
    _scrollPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _remindersKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target);
      }
    });
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
      options: [for (var d = DateTime.monday; d <= DateTime.sunday; d++) (d, _evening(d))],
      selected: current,
    );
    if (picked != null) await _save(SettingKeys.weeklySummaryDay, picked, reschedule: true);
  }

  Future<void> _confirmForget() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget everything it has learned?'),
        content: const Text(
          'Suggestions start again from your next entries. Your entries, categories and '
          'budgets stay as they are.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Forget')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _save(SettingKeys.learningResetAt, clock.now().millisecondsSinceEpoch);
    if (mounted && _problem == null) setState(() => _done = forgotMessage);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(storedSettingsProvider);
    if (async.hasError) {
      return const SettingsPage(
        title: _title,
        children: [AkEmptyNote('Settings could not load. Close Akatabo and open it again.')],
      );
    }
    if (!async.hasValue) return const SettingsPage(title: _title, children: []);

    if (_scrollPending) _scrollToReminders();
    final s = async.requireValue;
    T read<T>(SettingKey<T> key) => key.decode(s[key.name]);
    final at = read(SettingKeys.dailyReminderAt);
    final day = read(SettingKeys.weeklySummaryDay);

    return SettingsPage(
      title: _title,
      children: [
        Text(
          'Akatabo learns from your own entries, on this phone only. Switch off anything you '
          'do not want.',
          style: context.type.bodySm.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'What it does for you',
          children: [
            _NotedSwitchRow(
              label: 'Suggest a category',
              note: 'From the words you type when you add',
              value: read(SettingKeys.suggestCategory),
              onChanged: (v) => _save(SettingKeys.suggestCategory, v),
            ),
            _NotedSwitchRow(
              label: 'Forecast the month',
              note: 'Where your spending is heading by month end',
              value: read(SettingKeys.forecastMonth),
              onChanged: (v) => _save(SettingKeys.forecastMonth, v),
            ),
            _NotedSwitchRow(
              label: 'Point out unusual payments',
              note: 'Much larger, or at an odd time for you',
              value: read(SettingKeys.pointOutUnusual),
              onChanged: (v) => _save(SettingKeys.pointOutUnusual, v),
            ),
            _SegmentRow(
              label: 'How often it points them out',
              child: AkSegmented<UnusualHowOften>(
                semanticLabel: 'How often it points them out',
                segments: const [
                  AkSegment(UnusualHowOften.rarely, 'Rarely'),
                  AkSegment(UnusualHowOften.balanced, 'Balanced'),
                  AkSegment(UnusualHowOften.often, 'Often'),
                ],
                selected: read(SettingKeys.unusualHowOften),
                onChanged: (v) => _save(SettingKeys.unusualHowOften, v),
              ),
            ),
            _NotedSwitchRow(
              label: 'Notice regular payments',
              note: 'Such as Yaka, data bundles and rent',
              value: read(SettingKeys.noticeRegular),
              onChanged: (v) => _save(SettingKeys.noticeRegular, v),
            ),
            const _NoteRow(laterNote),
            _ActionRow(label: 'Forget everything it has learned', onTap: _confirmForget),
          ],
        ),
        SettingsSection(
          key: _remindersKey,
          label: 'Reminders',
          children: [
            SettingsSwitchRow(
              label: 'Remind me to add each day',
              value: read(SettingKeys.dailyReminder),
              onChanged: (v) => _switchReminder(SettingKeys.dailyReminder, v),
              divider: true,
            ),
            SettingsValueRow(
              title: 'At',
              value: _clock(at),
              onTap: () => _pickTime(at),
              divider: true,
            ),
            // One source of truth: each budget keeps its own warn level (Set a budget), and
            // this switch only says whether a notification is sent when it is reached.
            _NotedSwitchRow(
              label: 'Warn me when a budget is nearly used',
              note: "At each budget's own warn level, and again if it goes over",
              value: read(SettingKeys.budgetWarn),
              onChanged: (v) => _switchReminder(SettingKeys.budgetWarn, v),
            ),
            SettingsSwitchRow(
              label: 'Tell me before a regular payment',
              value: read(SettingKeys.regularReminder),
              onChanged: (v) => _switchReminder(SettingKeys.regularReminder, v),
              divider: true,
            ),
            SettingsSwitchRow(
              label: 'Weekly summary',
              value: read(SettingKeys.weeklySummary),
              onChanged: (v) => _switchReminder(SettingKeys.weeklySummary, v),
              divider: true,
            ),
            SettingsValueRow(title: 'Sent on', value: _evening(day), onTap: () => _pickDay(day)),
          ],
        ),
        if (_allowed == false &&
            _problem == null &&
            (read(SettingKeys.dailyReminder) ||
                read(SettingKeys.budgetWarn) ||
                read(SettingKeys.regularReminder) ||
                read(SettingKeys.weeklySummary)))
          const AkEmptyNote(notificationsBlockedMessage),
        if (_problem != null) AkEmptyNote(_problem!),
        if (_done != null) AkEmptyNote(_done!),
      ],
    );
  }
}

/// `20:00`: minutes after midnight on a 24-hour clock.
String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String _evening(int weekday) => '${weekdayNames[weekday - 1]} evening';

/// A switch row with a second line saying what the switch does.
class _NotedSwitchRow extends StatelessWidget {
  const _NotedSwitchRow({
    required this.label,
    required this.note,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s2h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The switch carries the label for screen readers; the note is read as text.
                ExcludeSemantics(child: Text(label, style: context.type.bodyMd)),
                Text(note, style: context.type.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s3),
          AkSwitch(label: label, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A label above a segmented choice, with a line under it.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: Text(label, style: context.type.bodyMd)),
          const SizedBox(height: AkSpace.s2),
          child,
        ],
      ),
    );
  }
}

/// A plain muted sentence inside a card, with a line under it.
class _NoteRow extends StatelessWidget {
  const _NoteRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
      child: Text(text, style: context.type.bodySm.copyWith(color: c.inkMuted)),
    );
  }
}

/// A full-width text action in `money-out`, for an action that cannot be undone.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSize.row),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
            child: Text(
              label,
              style: context.type.bodyMd.copyWith(
                color: context.colors.moneyOut,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
