import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_surfaces.dart';
import '../privacy/about_section.dart';
import 'settings_page.dart';

/// The Settings tab (Settings.html): the pages in three groups, each row with a tile, a
/// name, a line saying what it holds and a chevron.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _groups = <List<_Entry>>[
    [
      _Entry(
        AkIcons.sliders,
        'General',
        'Currency, language, dates, number style',
        Routes.settingsGeneral,
      ),
      _Entry(
        AkIcons.wallet,
        'Accounts',
        'Cash, MTN MoMo, Airtel Money, bank',
        Routes.settingsAccounts,
      ),
      _Entry(
        AkIcons.tag,
        'Categories',
        'Names, icons, colours, order, budgets',
        Routes.settingsCategories,
      ),
    ],
    [
      _Entry(
        AkIcons.sun,
        'Appearance',
        'Theme, colours, text size, charts',
        Routes.settingsAppearance,
      ),
      _Entry(AkIcons.house, 'Home screen', 'Choose the cards and their order', Routes.settingsHome),
      _Entry(
        AkIcons.trend,
        'Smart help',
        'Suggestions, forecast, unusual payments',
        Routes.settingsSmart,
      ),
      _Entry(
        AkIcons.bell,
        'Reminders',
        'Daily nudge, budget warnings, weekly summary',
        Routes.settingsReminders,
      ),
    ],
    [
      _Entry(
        AkIcons.lock,
        'Privacy and security',
        'App lock, hidden amounts',
        Routes.settingsPrivacy,
      ),
      _Entry(
        AkIcons.download,
        'Data and backup',
        'Export, back up, restore, delete',
        Routes.settingsData,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // The version appears once it is known; until then, and if it cannot be read, the line
    // is the same without it.
    final version = ref.watch(appVersionProvider).value;
    final footer = version == null || version.isEmpty
        ? 'Free, with no account and no adverts.'
        : 'Akatabo $version. Free, with no account and no adverts.';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
          children: [
            Semantics(header: true, child: Text('Settings', style: context.type.displayLg)),
            const SizedBox(height: AkSpace.s4),
            for (final group in _groups) ...[
              AkCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < group.length; i++)
                      _SettingsRow(
                        entry: group[i],
                        divider: i < group.length - 1,
                        onTap: () => context.push(group[i].route),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AkSpace.s3),
            ],
            const SizedBox(height: AkSpace.s1),
            Text(
              footer,
              style: context.type.caption.copyWith(color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.entry, required this.divider, required this.onTap});

  final _Entry entry;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${entry.title}, ${entry.subtitle}',
      onTap: onTap,
      child: AkListRow(
        leading: AkIconTile(
          icon: entry.icon,
          background: c.surfaceSunk,
          foreground: c.brandText,
          iconSize: AkSize.icon,
        ),
        title: entry.title,
        subtitle: entry.subtitle,
        titleWeight: FontWeight.w600,
        trailing: AkIcon(AkIcons.chevron, size: AkSize.iconSm, color: c.inkMuted),
        divider: divider,
        padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
        onTap: onTap,
      ),
    );
  }
}

class _Entry {
  const _Entry(this.icon, this.title, this.subtitle, this.route);
  final AkIcons icon;
  final String title;
  final String subtitle;
  final String route;
}
