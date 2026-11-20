import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';

/// Side padding of every row inside a settings card (value, switch, segment and action
/// rows), 14 as drawn, so their left edges line up.
const settingsRowSide = AkSpace.s3h;

/// The frame every Settings page shares: a back link to Settings, the page title, then sections.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Settings', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s4),
            Semantics(header: true, child: Text(title, style: context.type.displayLg)),
            const SizedBox(height: AkSpace.s4),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A labelled group of rows on a card, as the drawn Settings pages group them.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AkEyebrow(label),
          const SizedBox(height: AkSpace.s2),
          AkCard(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// One row: a title, the current value, and a chevron when the value can be changed.
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
    this.divider = false,
    this.chevron = false,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool divider;

  /// A chevron after the value. Settings rows are drawn without one (the whole row is the
  /// target); Filters draws one on its Dates row.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AkListRow(
      title: title,
      divider: divider,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                // The design system: the row shows the current value in ink-muted.
                style: context.type.body.copyWith(color: c.inkMuted),
                textAlign: TextAlign.end,
              ),
            ),
            if (chevron && onTap != null) ...[
              const SizedBox(width: AkSpace.s2),
              AkIcon(AkIcons.chevron, color: c.inkMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row with a visible label and a switch. [AkSwitch] only draws the switch, so the label
/// is drawn here; the switch keeps it for screen readers.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.divider = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.line)),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(child: Text(label, style: context.type.bodyMd)),
          ),
          const SizedBox(width: AkSpace.s3),
          AkSwitch(label: label, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "11th", "21st": the day of the month as it is written.
String ordinalDay(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return 'The $n$suffix';
}

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
