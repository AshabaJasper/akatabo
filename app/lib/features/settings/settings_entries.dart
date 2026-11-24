import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import 'settings_search.dart';

/// One page the Settings hub opens: its tile icon, name, summary line, route and the card
/// ([group]) it sits in.
class SettingsEntry implements SearchableSetting {
  const SettingsEntry({
    required this.group,
    required this.icon,
    required this.label,
    required this.description,
    required this.route,
    this.keywords = const [],
  });

  final int group;
  final AkIcons icon;
  @override
  final String label;
  @override
  final String description;
  final String route;
  @override
  final List<String> keywords;
}

/// Every Settings page, in the order the hub shows them. The hub draws its cards from this
/// list and the search filters this same list, so a page added here is listed and searchable.
const settingsEntries = <SettingsEntry>[
  SettingsEntry(
    group: 0,
    icon: AkIcons.sliders,
    label: 'General',
    description: 'Currency, language, dates, number style',
    route: Routes.settingsGeneral,
    keywords: ['UGX', 'shilling', 'month start', 'week start', 'new entry'],
  ),
  SettingsEntry(
    group: 0,
    icon: AkIcons.wallet,
    label: 'Accounts',
    description: 'Cash, MTN MoMo, Airtel Money, bank',
    route: Routes.settingsAccounts,
    keywords: ['mobile money', 'wallet', 'new account'],
  ),
  SettingsEntry(
    group: 0,
    icon: AkIcons.tag,
    label: 'Categories',
    description: 'Names, icons, colours, order, budgets',
    route: Routes.settingsCategories,
    keywords: ['money in', 'income', 'rename', 'hide'],
  ),
  SettingsEntry(
    group: 1,
    icon: AkIcons.sun,
    label: 'Appearance',
    description: 'Theme, colours, text size, charts',
    route: Routes.settingsAppearance,
    keywords: ['dark', 'light', 'font', 'corners', 'money colours'],
  ),
  SettingsEntry(
    group: 1,
    icon: AkIcons.house,
    label: 'Home screen',
    description: 'Choose the cards and their order',
    route: Routes.settingsHome,
    keywords: ['layout', 'sections'],
  ),
  SettingsEntry(
    group: 1,
    icon: AkIcons.trend,
    label: 'Smart help',
    description: 'Suggestions, forecast, unusual payments',
    route: Routes.settingsSmart,
    keywords: ['predictions', 'regular payments'],
  ),
  SettingsEntry(
    group: 1,
    icon: AkIcons.bell,
    label: 'Reminders',
    description: 'Daily nudge, budget warnings, weekly summary',
    route: Routes.settingsReminders,
    keywords: ['notifications', 'alerts'],
  ),
  SettingsEntry(
    group: 2,
    icon: AkIcons.lock,
    label: 'App lock',
    description: 'PIN, fingerprint or face, lock after',
    route: Routes.settingsLock,
    keywords: ['security', 'password', 'biometric'],
  ),
  SettingsEntry(
    group: 2,
    icon: AkIcons.check,
    label: 'Phone permissions',
    description: 'What this phone allows Akatabo',
    route: Routes.settingsPermissions,
    keywords: ['notifications', 'fingerprint'],
  ),
  SettingsEntry(
    group: 2,
    icon: AkIcons.phone,
    label: 'Privacy and security',
    description: 'Hidden amounts, the app switcher',
    route: Routes.settingsPrivacy,
    keywords: ['hide amounts'],
  ),
  SettingsEntry(
    group: 2,
    icon: AkIcons.download,
    label: 'Data and backup',
    description: 'Export, back up, restore, delete',
    route: Routes.settingsData,
    keywords: ['backup', 'password', 'CSV', 'Excel', 'PDF'],
  ),
];
