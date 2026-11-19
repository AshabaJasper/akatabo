import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import 'settings_page.dart';

/// The accounts the person pays from. A switched-off account stops being offered on Add;
/// entries already made keep it.
class AccountsSettingsScreen extends ConsumerStatefulWidget {
  const AccountsSettingsScreen({super.key});

  @override
  ConsumerState<AccountsSettingsScreen> createState() => _AccountsSettingsScreenState();
}

class _AccountsSettingsScreenState extends ConsumerState<AccountsSettingsScreen> {
  String? _problem;

  Future<void> _setEnabled(String id, {required bool enabled}) async {
    setState(() => _problem = null);
    try {
      await ref.read(accountRepositoryProvider).setEnabled(id, enabled: enabled);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider);
    if (accounts.hasError) {
      return const SettingsPage(
        title: 'Accounts',
        children: [AkEmptyNote('Accounts could not load. Close Akatabo and open it again.')],
      );
    }
    if (!accounts.hasValue) return const SettingsPage(title: 'Accounts', children: []);
    final list = accounts.requireValue;

    return SettingsPage(
      title: 'Accounts',
      children: [
        SettingsSection(
          label: 'Accounts you pay from',
          children: [
            for (final (i, a) in list.indexed)
              SettingsSwitchRow(
                label: a.name,
                value: a.enabled,
                divider: i < list.length - 1,
                onChanged: (v) => _setEnabled(a.id, enabled: v),
              ),
          ],
        ),
        if (list.isEmpty) const AkEmptyNote('No accounts yet.'),
        const SizedBox(height: AkSpace.s2),
        AkTextLink(
          'Add an account',
          icon: AkIcons.plus,
          onTap: () => context.push(Routes.settingsAccountNew),
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}
