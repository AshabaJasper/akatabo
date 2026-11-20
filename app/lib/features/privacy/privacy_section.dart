import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/security/lock_controller.dart';
import '../../services/security/privacy_settings.dart';
import '../../widgets/ak_empty_note.dart';
import '../settings/settings_page.dart';

/// Privacy and security on Privacy and data (SetPrivacy.html): Hide amounts, Blank the screen
/// in the app switcher, and a row to App lock, which has its own page since 21 November 2026.
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({super.key});

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  String? _problem;

  /// Only Android has the app-switcher handler (MainActivity.kt); the row is left out on
  /// iOS until one is written there, rather than offering a switch that does nothing.
  bool get _blankOffered => defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() => _problem = null);
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storedSettingsProvider);
    if (settingsAsync.hasError && !settingsAsync.hasValue) {
      return const AkEmptyNote('Privacy settings could not load. Close Akatabo and open it again.');
    }
    final s = settingsAsync.value ?? const <String, String>{};
    T read<T>(SettingKey<T> key) => key.decode(s[key.name]);
    final pinAsync = ref.watch(pinIsSetProvider);
    final lockOn = read(PrivacyKeys.lockOn) && (pinAsync.value ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          label: 'Privacy and security',
          children: [
            SettingsValueRow(
              title: 'App lock',
              // Blank until the PIN check answers, rather than a wrong "Off".
              value: pinAsync.hasValue ? (lockOn ? 'On' : 'Off') : '',
              onTap: () => context.push('${Routes.settingsLock}?from=privacy'),
              divider: true,
            ),
            SettingsSwitchRow(
              label: 'Hide amounts',
              detail: 'Show dots until you tap a figure',
              value: read(PrivacyKeys.hideAmounts),
              onChanged: (v) => _save(PrivacyKeys.hideAmounts, v),
              divider: _blankOffered,
            ),
            if (_blankOffered)
              SettingsSwitchRow(
                label: 'Blank the screen in the app switcher',
                detail: 'So figures do not show in recent apps',
                value: read(PrivacyKeys.blankInSwitcher),
                onChanged: (v) => _save(PrivacyKeys.blankInSwitcher, v),
              ),
          ],
        ),
        if (_problem != null) ...[AkEmptyNote(_problem!), const SizedBox(height: AkSpace.s4)],
      ],
    );
  }
}
