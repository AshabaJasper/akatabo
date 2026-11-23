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
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../add/amount_text.dart';
import '../transactions/transactions_providers.dart';
import 'settings_page.dart';

/// The accounts the person pays from. A switched-off account stops being offered on Add;
/// entries already made keep it. Edit opens Edit account, where it can also be deleted.
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

  /// Asks what is in [account] now and saves it as the account's balance from this moment.
  Future<void> _setBalance(Account account) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BalanceSheet(account: account),
    );
    if (amount == null || !mounted) return;
    setState(() => _problem = null);
    try {
      await ref.read(accountRepositoryProvider).setBalanceToday(account.id, amount);
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
                action: Semantics(
                  button: true,
                  label: 'Edit ${a.name}',
                  excludeSemantics: true,
                  onTap: () => context.push(Routes.settingsAccountEdit(a.id)),
                  child: AkTextLink(
                    'Edit',
                    onTap: () => context.push(Routes.settingsAccountEdit(a.id)),
                  ),
                ),
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
          _BalancesSection(accounts: list, balances: balancesOf(list, rows), onSet: _setBalance),
        ],
      ],
    );
  }
}

/// What is in each account today and the total. Each balance is what the person last said was
/// in the account plus every entry dated since; tapping a row says it again. An account whose
/// balance was never set reads "Not set" and stays out of the total. An account switched off
/// from the totals keeps its own line but is left out of the total, and the line under the
/// total says which. A switched-off account with no balance to show is not listed, and the
/// note only names accounts that are listed.
class _BalancesSection extends StatelessWidget {
  const _BalancesSection({required this.accounts, required this.balances, required this.onSet});

  final List<Account> accounts;
  final Balances balances;
  final ValueChanged<Account> onSet;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final a in accounts)
        if (a.enabled || (balances.byAccount[a.id] ?? 0) != 0) a,
    ];
    final shownIds = {for (final a in shown) a.id};
    final leftOut = [
      for (final a in balances.leftOut)
        if (shownIds.contains(a.id)) a.name,
    ];
    final anyNotSet = balances.notSet.any((a) => shownIds.contains(a.id));
    final note = [
      'Tap an account to say what is in it now; entries from then on change it.',
      if (anyNotSet) 'Accounts not set are not in the total.',
      if (leftOut.isNotEmpty) 'Not counted in the total: ${leftOut.join(', ')}.',
    ].join(' ');
    return SettingsSection(
      label: 'What is in them today',
      children: [
        for (final a in shown)
          SettingsValueRow(
            title: a.name,
            value: switch (balances.byAccount[a.id]) {
              final int balance => formatUgx(balance),
              null => 'Not set',
            },
            divider: true,
            onTap: () => onSet(a),
          ),
        SettingsValueRow(title: 'Total', value: formatUgx(balances.total), divider: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
          child: Text(note, style: context.type.bodySm.copyWith(color: context.colors.inkMuted)),
        ),
      ],
    );
  }
}

/// Asks what is in one account now, in UGX. Pops with the amount, or nothing when dismissed.
class _BalanceSheet extends StatefulWidget {
  const _BalanceSheet({required this.account});

  final Account account;

  @override
  State<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<_BalanceSheet> {
  final _amount = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    if (_amount.text.trim().isEmpty) {
      setState(() => _error = 'Type what is in it, or 0 if it is empty.');
      return;
    }
    Navigator.of(context).pop(parseAmount(_amount.text));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      // Lifts the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'What is in ${widget.account.name} now',
                style: t.title.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: AkSpace.s2),
            Text(
              'Entries from now on add to it or take from it. Earlier entries are already in it.',
              style: t.bodySm.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: 'Amount, UGX',
              controller: _amount,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              textInputAction: TextInputAction.done,
              figures: true,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AkSpace.s4),
            AkPrimaryButton(label: 'Save', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
