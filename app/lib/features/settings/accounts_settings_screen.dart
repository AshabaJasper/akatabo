import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/balances.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../transactions/transactions_providers.dart';
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
    final rows = ref.watch(allTransactionsProvider).value;

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
        if (rows != null && list.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s6),
          _BalancesSection(accounts: list, balances: balancesOf(list, rows)),
        ],
      ],
    );
  }
}

/// What is in each account today and the total, from what each account started with and every
/// entry since. An account switched off from the totals keeps its own line but is left out of
/// the total, and the line under the total says which. A switched-off account with nothing in
/// it is not listed.
class _BalancesSection extends StatelessWidget {
  const _BalancesSection({required this.accounts, required this.balances});

  final List<Account> accounts;
  final Balances balances;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final a in accounts)
        if (a.enabled || balances.byAccount[a.id] != 0) a,
    ];
    final leftOut = balances.leftOut.map((a) => a.name).toList();
    return SettingsSection(
      label: 'What is in them today',
      children: [
        for (final a in shown)
          SettingsValueRow(
            title: a.name,
            value: formatUgx(balances.byAccount[a.id]!),
            divider: true,
          ),
        SettingsValueRow(title: 'Total', value: formatUgx(balances.total), divider: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
          child: Text(
            leftOut.isEmpty
                ? 'Each account starts from what was in it when you added it.'
                : 'Each account starts from what was in it when you added it. Not counted in '
                      'the total: ${leftOut.join(', ')}.',
            style: context.type.bodySm.copyWith(color: context.colors.inkMuted),
          ),
        ),
      ],
    );
  }
}
