import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/transaction_filter.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../home/home_providers.dart';
import '../settings/settings_page.dart';
import '../transactions/transactions_providers.dart';
import 'date_choice_providers.dart';
import 'transaction_filter_providers.dart';

String _orderLabel(FilterOrder o) => switch (o) {
  FilterOrder.newest => 'Newest',
  FilterOrder.largest => 'Largest',
  FilterOrder.oldest => 'Oldest',
};

final _day = DateFormat('d MMM yyyy');

/// "5 to 19 Nov 2026", or "All dates" when no range is chosen.
String _datesLabel(Period? p) =>
    p == null ? 'All dates' : '${_day.format(p.start)} to ${_day.format(p.lastDate)}';

/// Parses a typed amount: digits only, commas allowed, empty means no limit.
int? _parseAmount(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// Filters for All transactions. Each choice applies at once; the button shows how many
/// entries match and returns to the list.
class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key});

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends ConsumerState<FiltersScreen> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _amountProblem;

  @override
  void initState() {
    super.initState();
    final f = ref.read(transactionFilterProvider);
    _min = TextEditingController(text: f.minAmount?.toString() ?? '');
    _max = TextEditingController(text: f.maxAmount?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _setAmounts() {
    final min = _parseAmount(_min.text);
    final max = _parseAmount(_max.text);
    if (min != null && max != null && min > max) {
      // Neither limit applies until the pair is in order, so the list never narrows by a pair
      // the fields no longer show as valid. Show is disabled meanwhile.
      setState(
        () => _amountProblem = 'The lowest amount is above the highest. No limit applies yet.',
      );
      ref.read(transactionFilterProvider.notifier).setAmounts();
      return;
    }
    setState(() => _amountProblem = null);
    ref.read(transactionFilterProvider.notifier).setAmounts(min: min, max: max);
  }

  void _clearAll() {
    _min.clear();
    _max.clear();
    setState(() => _amountProblem = null);
    ref.read(transactionFilterProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final filter = ref.watch(transactionFilterProvider);
    final period = ref.watch(chosenPeriodProvider);
    final categories = ref.watch(allCategoriesProvider).value ?? const <Category>[];
    // Every account, not only the enabled ones: an account switched off later still has
    // entries, and its chip must stay visible while it narrows the list.
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final all = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];
    final matching = all.where((tx) => matchesFilter(tx, filter, period)).length;
    final changed = filter.narrows || period != null || filter.order != FilterOrder.newest;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Transactions', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Filters', style: t.displayLg.copyWith(color: c.ink)),
                  ),
                ),
                if (changed) AkTextLink('Clear all', onTap: _clearAll),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            SettingsSection(
              label: 'Categories',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AkSpace.s4),
                  child: Wrap(
                    spacing: AkSpace.s2,
                    runSpacing: AkSpace.s2,
                    children: [
                      for (final cat in categories)
                        AkChip(
                          label: cat.name,
                          selected: filter.categoryIds.contains(cat.id),
                          onTap: () =>
                              ref.read(transactionFilterProvider.notifier).toggleCategory(cat.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              label: 'Paid from',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AkSpace.s4),
                  child: Wrap(
                    spacing: AkSpace.s2,
                    runSpacing: AkSpace.s2,
                    children: [
                      for (final a in accounts)
                        AkChip(
                          label: a.name,
                          selected: filter.accountIds.contains(a.id),
                          onTap: () =>
                              ref.read(transactionFilterProvider.notifier).toggleAccount(a.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              label: 'Amount, UGX',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AkSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AkTextField(
                        label: 'At least, UGX',
                        controller: _min,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _setAmounts(),
                      ),
                      const SizedBox(height: AkSpace.s3),
                      AkTextField(
                        label: 'At most, UGX',
                        controller: _max,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.done,
                        errorText: _amountProblem,
                        onChanged: (_) => _setAmounts(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsSection(
              label: 'Dates',
              children: [
                SettingsValueRow(
                  title: 'Dates',
                  value: _datesLabel(period),
                  onTap: () => context.push(Routes.chooseDates),
                ),
              ],
            ),
            SettingsSection(
              label: 'Show only',
              children: [
                SettingsSwitchRow(
                  label: 'Only ones with a fee',
                  value: filter.onlyFee,
                  divider: true,
                  onChanged: (v) => ref.read(transactionFilterProvider.notifier).setOnlyFee(on: v),
                ),
                SettingsSwitchRow(
                  label: 'Only ones marked unusual',
                  value: filter.onlyUnusual,
                  onChanged: (v) =>
                      ref.read(transactionFilterProvider.notifier).setOnlyUnusual(on: v),
                ),
              ],
            ),
            SettingsSection(
              label: 'Order',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AkSpace.s4),
                  child: AkSegmented<FilterOrder>(
                    semanticLabel: 'Order',
                    selected: filter.order,
                    onChanged: (o) => ref.read(transactionFilterProvider.notifier).setOrder(o),
                    segments: [for (final o in FilterOrder.values) AkSegment(o, _orderLabel(o))],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            AkPrimaryButton(
              label: matching == 1 ? 'Show 1 transaction' : 'Show $matching transactions',
              onPressed: _amountProblem == null ? () => closeScreen(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}
