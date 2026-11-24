import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formats.dart';
import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/settings/remembered_rates.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_pickers.dart';
import '../add/add_providers.dart';
import 'settings_page.dart';

/// Money and dates, how amounts are written and how a new entry starts. Each change is saved at once.
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

  Future<void> _setDefault(String accountId) async {
    setState(() => _problem = null);
    try {
      await ref.read(accountRepositoryProvider).setDefault(accountId);
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
    final dateStyle = SettingKeys.dateStyle.decode(s[SettingKeys.dateStyle.name]);
    final amountStyle = SettingKeys.amountStyle.decode(s[SettingKeys.amountStyle.name]);
    final direction = SettingKeys.newEntryDirection.decode(s[SettingKeys.newEntryDirection.name]);
    // The accounts Add offers, and the one it opens on, worked out as Add does.
    final accounts = ref.watch(enabledAccountsProvider).value ?? const <Account>[];
    final firstPick = firstPickAccount(accounts);

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
                final picked = await showAkChoiceSheet<int>(
                  context,
                  title: 'Month starts on',
                  selected: monthStart,
                  note:
                      'Monthly totals and budgets start on this day. It goes up to the 28th '
                      'so that every month has it.',
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
                final picked = await showAkChoiceSheet<int>(
                  context,
                  title: 'Week starts on',
                  selected: weekStart,
                  options: [
                    for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                      (d, weekdayNames[d - 1]),
                  ],
                );
                if (picked != null) await _save(SettingKeys.weekStartsOn, picked);
              },
            ),
            SettingsValueRow(
              title: 'Date style',
              value: dateStyle.example,
              divider: true,
              onTap: () async {
                final picked = await showAkChoiceSheet<DateStyle>(
                  context,
                  title: 'Date style',
                  selected: dateStyle,
                  options: [for (final d in DateStyle.values) (d, d.example)],
                );
                if (picked != null) await _save(SettingKeys.dateStyle, picked);
              },
            ),
            // UGX is the home currency. The rates typed for other currencies, and a converter,
            // live on their own page.
            SettingsValueRow(
              title: 'Currencies and rates',
              value: _ratesSummary(rememberedRates(s)),
              onTap: () => context.push(Routes.settingsCurrencies),
              chevron: true,
              divider: true,
            ),
            const SettingsValueRow(title: 'Language', value: 'English', divider: true),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: settingsRowSide,
                vertical: AkSpace.s3,
              ),
              child: Text(
                'Akatabo counts in Ugandan shillings and is in English only, so these two '
                'cannot be changed.',
                style: context.type.bodySm.copyWith(color: context.colors.inkMuted),
              ),
            ),
          ],
        ),
        SettingsSection(
          label: 'Numbers and entry',
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.line)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: settingsRowSide,
                vertical: AkSpace.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How amounts are written', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<AmountStyle>(
                    semanticLabel: 'How amounts are written',
                    segments: const [
                      AkSegment(AmountStyle.full, '1,284,000'),
                      AkSegment(AmountStyle.short, '1.28M'),
                    ],
                    selected: amountStyle,
                    onChanged: (v) => _save(SettingKeys.amountStyle, v),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.line)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: settingsRowSide,
                vertical: AkSpace.s4,
              ),
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
            SettingsValueRow(
              title: 'Picked first when you add',
              value: firstPick?.name ?? 'No account yet',
              onTap: accounts.isEmpty
                  ? null
                  : () async {
                      final picked = await showAkChoiceSheet<String>(
                        context,
                        title: 'Picked first when you add',
                        selected: firstPick?.id,
                        options: [for (final a in accounts) (a.id, a.name)],
                      );
                      // Saved unless it is already the marked default. Picking the account
                      // shown only as a fallback (the default is switched off) marks it, so
                      // Add does not jump back when the old default is switched on again.
                      final alreadyMarked = picked == firstPick?.id && firstPick!.isDefault;
                      if (picked != null && !alreadyMarked) await _setDefault(picked);
                    },
            ),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}

/// The Currencies and rates row's value: "UGX only", or how many rates are remembered.
String _ratesSummary(Map<String, int> rates) => switch (rates.length) {
  0 => 'UGX only',
  1 => '1 rate remembered',
  _ => '${rates.length} rates remembered',
};
