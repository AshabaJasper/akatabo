import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../forecast/forecast_providers.dart';
import '../regular/regular_providers.dart';
import 'settings_page.dart';
import 'smart_rows.dart';

/// Smart help: the things Akatabo learns from your entries, what each one has noticed, and
/// switches for each. Reminders are on their own page.
///
/// "Forecast the month" hides the forecast. Forgetting what it learned keeps every entry.
class SmartHelpScreen extends ConsumerStatefulWidget {
  const SmartHelpScreen({super.key});

  @override
  ConsumerState<SmartHelpScreen> createState() => _SmartHelpScreenState();
}

const forgotMessage = 'Smart help has forgotten what it learned. Your entries are unchanged.';

class _SmartHelpScreenState extends ConsumerState<SmartHelpScreen> {
  String? _problem;
  String? _done;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() {
      _problem = null;
      _done = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  Future<void> _confirmForget() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget everything it has learned?'),
        content: const Text(
          'Suggestions start again from your next entries. Your entries, categories and '
          'budgets stay as they are.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Forget')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _save(SettingKeys.learningResetAt, clock.now().millisecondsSinceEpoch);
    if (mounted && _problem == null) setState(() => _done = forgotMessage);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final async = ref.watch(storedSettingsProvider);
    const title = 'Smart help';
    if (async.hasError) {
      return const SettingsPage(
        title: title,
        children: [AkEmptyNote('Settings could not load. Close Akatabo and open it again.')],
      );
    }
    if (!async.hasValue) return const SettingsPage(title: title, children: []);

    final s = async.requireValue;
    T read<T>(SettingKey<T> key) => readSetting(s, key);
    final history = ref.watch(forecastHistoryProvider) ?? const [];
    final regularCount = ref.watch(activeRegularProvider).value?.length ?? 0;

    // How far the saved forecasts were from what was spent, averaged over the saved months.
    // A month forecast at nothing cannot say how far out it was, so it is left out.
    final usable = [
      for (final p in history)
        if (p.point > 0) p,
    ];
    final within = usable.isEmpty
        ? null
        : usable.fold(0.0, (sum, p) => sum + ((p.actual - p.point) / p.point).abs()) /
              usable.length;
    final accuracy = within == null
        ? 'No saved months yet'
        : 'Within about ${math.max(1, (within * 100).round())}%';

    return SettingsPage(
      title: title,
      children: [
        Text(
          'Akatabo learns from your own entries, on this phone only. Switch off anything you '
          'do not want.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'What it has learned',
          children: [
            SettingsValueRow(title: 'Forecast accuracy', value: accuracy, divider: true),
            SettingsValueRow(
              title: 'Regular payments noticed',
              value: '$regularCount',
              divider: true,
            ),
          ],
        ),
        SettingsSection(
          label: 'What it does for you',
          children: [
            NotedSwitchRow(
              label: 'Suggest a category',
              note: 'From the words you type when you add',
              value: read(SettingKeys.suggestCategory),
              onChanged: (v) => _save(SettingKeys.suggestCategory, v),
            ),
            NotedSwitchRow(
              label: 'Forecast the month',
              note: 'Where your spending is heading by month end',
              value: read(SettingKeys.forecastMonth),
              onChanged: (v) => _save(SettingKeys.forecastMonth, v),
            ),
            NotedSwitchRow(
              label: 'Point out unusual payments',
              note: 'Much larger, or at an odd time for you',
              value: read(SettingKeys.pointOutUnusual),
              onChanged: (v) => _save(SettingKeys.pointOutUnusual, v),
            ),
            SegmentRow(
              label: 'How often it points them out',
              child: AkSegmented<UnusualHowOften>(
                semanticLabel: 'How often it points them out',
                segments: const [
                  AkSegment(UnusualHowOften.rarely, 'Rarely'),
                  AkSegment(UnusualHowOften.balanced, 'Balanced'),
                  AkSegment(UnusualHowOften.often, 'Often'),
                ],
                selected: read(SettingKeys.unusualHowOften),
                onChanged: (v) => _save(SettingKeys.unusualHowOften, v),
              ),
            ),
            NotedSwitchRow(
              label: 'Notice regular payments',
              note: 'Such as Yaka, data bundles and rent',
              value: read(SettingKeys.noticeRegular),
              onChanged: (v) => _save(SettingKeys.noticeRegular, v),
            ),
            ActionRow(label: 'Forget everything it has learned', onTap: _confirmForget),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
        if (_done != null) AkEmptyNote(_done!),
      ],
    );
  }
}
