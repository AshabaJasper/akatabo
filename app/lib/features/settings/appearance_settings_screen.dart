import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import 'settings_page.dart';

String _capitalised(String name) => '${name[0].toUpperCase()}${name.substring(1)}';

/// Theme, text size and corners. Each change is saved at once and rebuilds the app's theme,
/// because the app reads these from storage (see storedAppearanceProvider).
class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  String? _problem;

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
    final settings = ref.watch(storedSettingsProvider);
    if (settings.hasError) {
      return const SettingsPage(
        title: 'Appearance',
        children: [AkEmptyNote('Appearance could not load. Close Akatabo and open it again.')],
      );
    }
    if (!settings.hasValue) return const SettingsPage(title: 'Appearance', children: []);
    final look = ref.watch(storedAppearanceProvider);

    return SettingsPage(
      title: 'Appearance',
      children: [
        SettingsSection(
          label: 'Look',
          children: [
            Padding(
              padding: const EdgeInsets.all(AkSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<ThemeMode>(
                    semanticLabel: 'Theme',
                    segments: const [
                      AkSegment(ThemeMode.light, 'Light'),
                      AkSegment(ThemeMode.dark, 'Dark'),
                      AkSegment(ThemeMode.system, 'Follow phone'),
                    ],
                    selected: look.themeMode,
                    onChanged: (v) => _save(SettingKeys.theme, v),
                  ),
                  const SizedBox(height: AkSpace.s4),
                  Text('Text size', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<AkTextSize>(
                    semanticLabel: 'Text size',
                    segments: [
                      for (final v in AkTextSize.values) AkSegment(v, _capitalised(v.name)),
                    ],
                    selected: look.textSize,
                    onChanged: (v) => _save(SettingKeys.textSize, v),
                  ),
                  const SizedBox(height: AkSpace.s4),
                  Text('Corners', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<AkCorners>(
                    semanticLabel: 'Corners',
                    segments: [
                      for (final v in AkCorners.values) AkSegment(v, _capitalised(v.name)),
                    ],
                    selected: look.corners,
                    onChanged: (v) => _save(SettingKeys.corners, v),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}
