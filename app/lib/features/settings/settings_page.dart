import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_surfaces.dart';

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
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AkListRow(
      title: title,
      divider: divider,
      onTap: onTap,
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: context.type.bodyMd.copyWith(color: c.ink),
                textAlign: TextAlign.end,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AkSpace.s2),
              AkIcon(AkIcons.chevron, color: c.ink),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks the person to choose one option from a list, and returns the chosen value or null.
Future<T?> pickSetting<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
}) => showDialog<T>(
  context: context,
  builder: (ctx) => SimpleDialog(
    title: Text(title),
    children: [
      for (final (value, label) in options)
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
            child: Text(label),
          ),
        ),
    ],
  ),
);

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
