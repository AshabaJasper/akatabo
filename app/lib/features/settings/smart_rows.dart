import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import 'settings_page.dart';

/// Rows shared by Smart help and Reminders: a switch with a note under it, a segmented
/// choice, and a full-width action in the money-out colour.

/// `20:00`: minutes after midnight on a 24-hour clock.
String clockText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String eveningText(int weekday) => '${weekdayNames[weekday - 1]} evening';

/// A switch row with a second line saying what the switch does.
class NotedSwitchRow extends StatelessWidget {
  const NotedSwitchRow({
    super.key,
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
class SegmentRow extends StatelessWidget {
  const SegmentRow({super.key, required this.label, required this.child});

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

/// A full-width text action. [destructive] takes the money-out colour, for an action that
/// cannot be undone; otherwise it is the brand colour.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.label, required this.onTap, this.destructive = true});

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                color: destructive ? c.moneyOut : c.brandText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the Smart help and Reminders screens read a setting by its key.
T readSetting<T>(Map<String, String> settings, SettingKey<T> key) => key.decode(settings[key.name]);
