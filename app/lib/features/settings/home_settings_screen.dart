import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_empty_note.dart';
import 'home_layout.dart';
import 'settings_page.dart';

/// Chooses which sections Home shows. Each switch saves at once and Home redraws.
class HomeSettingsScreen extends ConsumerStatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  ConsumerState<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends ConsumerState<HomeSettingsScreen> {
  String? _problem;

  Future<void> _save(BoolSetting key, bool on) async {
    setState(() => _problem = null);
    try {
      await ref.read(settingsRepositoryProvider).write(key, on);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storedSettingsProvider);
    if (settings.hasError) {
      return const SettingsPage(
        title: 'Home screen',
        children: [AkEmptyNote('Home settings could not load. Close Akatabo and open it again.')],
      );
    }
    final layout = ref.watch(homeLayoutProvider);

    return SettingsPage(
      title: 'Home screen',
      children: [
        SettingsSection(
          label: 'Sections',
          // In the order Home draws them, as SetAppearance.html lists them.
          children: [
            _switchRow(
              context,
              'Three figures in the header',
              layout.headerTiles,
              SettingKeys.homeShowHeaderTiles,
              divider: true,
            ),
            _switchRow(
              context,
              'Forecast card',
              layout.forecast,
              SettingKeys.homeShowForecast,
              divider: true,
            ),
            _switchRow(
              context,
              'Where it went',
              layout.whereItWent,
              SettingKeys.homeShowWhereItWent,
              divider: true,
            ),
            _switchRow(
              context,
              'Latest transactions',
              layout.latest,
              SettingKeys.homeShowLatest,
              divider: true,
            ),
            _switchRow(context, 'Budgets at a glance', layout.budgets, SettingKeys.homeShowBudgets),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }

  Widget _switchRow(
    BuildContext context,
    String label,
    bool value,
    BoolSetting key, {
    bool divider = false,
  }) => SettingsSwitchRow(
    label: label,
    value: value,
    divider: divider,
    onChanged: (v) => _save(key, v),
  );
}
