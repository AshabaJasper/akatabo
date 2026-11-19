import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/db/tables.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import 'settings_page.dart';

/// Money and dates, and how a new entry starts. Each change is saved at once.
class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
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
    final async = ref.watch(storedSettingsProvider);
    if (async.hasError) {
      return const SettingsPage(
        title: 'General',
        children: [AkEmptyNote('Settings could not load. Close Akatabo and open it again.')],
      );
    }
    if (!async.hasValue) return const SettingsPage(title: 'General', children: []);

    final s = async.requireValue;
    final monthStart = SettingKeys.monthStartsOn.decode(s[SettingKeys.monthStartsOn.name]);
    final weekStart = SettingKeys.weekStartsOn.decode(s[SettingKeys.weekStartsOn.name]);
    final direction = SettingKeys.newEntryDirection.decode(s[SettingKeys.newEntryDirection.name]);

    return SettingsPage(
      title: 'General',
      children: [
        SettingsSection(
          label: 'Money and dates',
          children: [
            SettingsValueRow(
              title: 'Month starts on',
              value: ordinalDay(monthStart),
              divider: true,
              onTap: () async {
                final picked = await pickSetting<int>(
                  context,
                  title: 'Month starts on',
                  options: [for (var n = 1; n <= 28; n++) (n, ordinalDay(n))],
                );
                if (picked != null) await _save(SettingKeys.monthStartsOn, picked);
              },
            ),
            SettingsValueRow(
              title: 'Week starts on',
              value: weekdayNames[weekStart - 1],
              divider: true,
              onTap: () async {
                final picked = await pickSetting<int>(
                  context,
                  title: 'Week starts on',
                  options: [
                    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                      (d, weekdayNames[d - 1]),
                  ],
                );
                if (picked != null) await _save(SettingKeys.weekStartsOn, picked);
              },
            ),
            const SettingsValueRow(
              title: 'Currency',
              value: 'UGX, Ugandan shilling',
              divider: true,
            ),
            const SettingsValueRow(title: 'Language', value: 'English'),
          ],
        ),
        SettingsSection(
          label: 'Numbers and entry',
          children: [
            Padding(
              padding: const EdgeInsets.all(AkSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A new entry starts as', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<Direction>(
                    semanticLabel: 'A new entry starts as',
                    segments: const [
                      AkSegment(Direction.moneyOut, 'Money out'),
                      AkSegment(Direction.moneyIn, 'Money in'),
                    ],
                    selected: direction == Direction.moneyIn
                        ? Direction.moneyIn
                        : Direction.moneyOut,
                    onChanged: (d) => _save(SettingKeys.newEntryDirection, d),
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
