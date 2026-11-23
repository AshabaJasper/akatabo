import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/contrast.dart';
import '../../core/theme/token_colour.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../add/amount_text.dart';
import 'settings_page.dart';

/// The four kinds New account offers, as drawn. The two default mobile money accounts keep
/// their own kinds (`mtn`, `airtel`); one the person adds is `mobile`.
const List<(AccountKind, String)> newAccountKinds = [
  (AccountKind.cash, 'Cash'),
  (AccountKind.mobile, 'Mobile'),
  (AccountKind.bank, 'Bank'),
  (AccountKind.other, 'Other'),
];

/// The names screen readers say for [AccountRepository.accountColourTokens], in order.
const Map<String, String> accountColourNames = {
  'acct-mtn': 'Yellow',
  'acct-airtel': 'Red',
  'acct-bank': 'Blue',
  'acct-cash': 'Olive',
  'cat-purple': 'Purple',
  'cat-teal': 'Teal',
};

/// Adds an account the person pays from, with everything drawn on New account: name, kind,
/// colour, what is in it today, and the three switches. Saved accounts appear on the Accounts
/// page and on Add.
///
/// With [editId] it is Edit account: the same form filled from that account, without "What
/// is in it today" (the Accounts page sets that), and with Delete under it. Delete asks first,
/// and while entries use the account it offers to switch it off instead.
class NewAccountScreen extends ConsumerStatefulWidget {
  const NewAccountScreen({super.key, this.editId});

  final String? editId;

  @override
  ConsumerState<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends ConsumerState<NewAccountScreen> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  AccountKind _kind = AccountKind.other;

  /// The chosen colour, or null to follow the kind until the person picks one.
  String? _pickedColour;
  bool _askFee = true;
  bool _makeDefault = false;
  bool _countInTotals = true;

  /// Kept apart, so each shows in one place: a name problem under Name, a save problem
  /// under the button.
  String? _nameError;
  String? _problem;
  bool _saving = false;

  String get _colour => _pickedColour ?? AccountRepository.colourForKind(_kind);

  /// The account being edited, once its values are in the form.
  Account? _original;
  bool get _editing => widget.editId != null;

  /// Fills the form from [a] once. The two default mobile money accounts have kinds of their
  /// own that the form shows as Mobile; saving keeps theirs unless another kind is picked.
  void _fill(Account a) {
    _original = a;
    _name.text = a.name;
    _kind = switch (a.kind) {
      AccountKind.mtn || AccountKind.airtel => AccountKind.mobile,
      final k => k,
    };
    _pickedColour = AccountRepository.accountColourTokens.contains(a.colourToken)
        ? a.colourToken
        : null;
    _askFee = a.askFeeEachTime;
    _countInTotals = a.countInTotals;
    _makeDefault = a.isDefault;
  }

  AccountKind get _kindToSave {
    final before = _original?.kind;
    final keepOwn =
        _kind == AccountKind.mobile && (before == AccountKind.mtn || before == AccountKind.airtel);
    return keepOwn ? before! : _kind;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Done on the keyboard and the button can both fire; only one save may run.
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Give the account a name.';
        _problem = null;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _problem = null;
      _saving = true;
    });
    try {
      final original = _original;
      if (original != null) {
        await ref
            .read(accountRepositoryProvider)
            .update(
              original.id,
              name: name,
              kind: _kindToSave,
              colourToken: _colour,
              askFeeEachTime: _askFee,
              countInTotals: _countInTotals,
              makeDefault: _makeDefault == original.isDefault ? null : _makeDefault,
            );
        if (mounted) await _leave();
        return;
      }
      await ref
          .read(accountRepositoryProvider)
          .add(
            name: name,
            kind: _kind,
            colourToken: _colour,
            // Left empty, the balance stays unset rather than claiming the account holds 0.
            openingBalance: _opening.text.trim().isEmpty ? null : parseAmount(_opening.text),
            askFeeEachTime: _askFee,
            countInTotals: _countInTotals,
            makeDefault: _makeDefault,
          );
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _problem = _editing
              ? 'The changes could not be saved. Try again.'
              : 'The account could not be saved. Try again.';
        });
      }
      return;
    }
    if (mounted) await _leave();
  }

  /// Back to Accounts. Opened as the first route (a deep link) there is nothing to pop, so it
  /// goes to the Accounts page instead of staying open.
  Future<void> _leave() async {
    final router = GoRouter.maybeOf(context);
    if (router != null && !router.canPop()) {
      router.go(Routes.settingsAccounts);
      return;
    }
    await closeScreen(context);
  }

  /// Delete, as the rules say: refused while entries use the account (switching it off is
  /// offered instead, so those entries keep it), refused for the only account switched on,
  /// and otherwise
  /// asked first, because it cannot be undone.
  Future<void> _delete() async {
    final a = _original;
    if (a == null || _saving) return;
    setState(() => _problem = null);
    final repo = ref.read(accountRepositoryProvider);
    final int used;
    try {
      used = await repo.usedBy(a.id);
    } on Object {
      if (mounted) setState(() => _problem = '${a.name} could not be deleted. Try again.');
      return;
    }
    if (!mounted) return;
    if (used > 0) {
      final off = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${a.name} is used by $used ${used == 1 ? 'entry' : 'entries'}'),
          content: const Text(
            'An account with entries cannot be deleted. Switch it off instead: Add stops '
            'offering it, and its entries keep it.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            if (a.enabled)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Switch it off'),
              ),
          ],
        ),
      );
      if (off != true || !mounted) return;
      final done = await saveOrSay(
        context,
        () => repo.setEnabled(a.id, enabled: false),
        failed: '${a.name} could not be switched off. Try again.',
      );
      if (done && mounted) {
        showAkMessage(context, '${a.name} switched off.');
        await _leave();
      }
      return;
    }
    final others = [
      for (final o in ref.read(allAccountsProvider).value ?? const <Account>[])
        if (o.id != a.id) o,
    ];
    if (others.isEmpty || (a.enabled && !others.any((o) => o.enabled))) {
      setState(() => _problem = 'Akatabo needs one account to add to, so this one stays.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${a.name}?'),
        content: const Text('No entries use it. Deleting it cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final done = await saveOrSay(
      context,
      () => repo.delete(a.id),
      failed: '${a.name} could not be deleted. Try again.',
    );
    if (done && mounted) {
      showAkMessage(context, '${a.name} deleted.');
      await _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final enabled = ref.watch(enabledAccountsProvider).value ?? const <Account>[];
    final firstNow = firstPickAccount(enabled);
    if (_editing && _original == null) {
      final all = ref.watch(allAccountsProvider);
      final found = all.value?.where((a) => a.id == widget.editId).firstOrNull;
      if (found != null) {
        _fill(found);
      } else {
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
              children: [
                AkBackLink('Accounts', onTap: _leave),
                if (all.hasError || all.hasValue) ...[
                  const SizedBox(height: AkSpace.s4),
                  AkEmptyNote(
                    all.hasError
                        ? 'This account could not load. Go back and try again.'
                        : 'This account is no longer here.',
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Accounts', onTap: _leave),
            const SizedBox(height: AkSpace.s1),
            Semantics(
              header: true,
              child: Text(_editing ? 'Edit account' : 'New account', style: t.displayLg),
            ),
            const SizedBox(height: AkSpace.s2),
            Text(
              'An account is anywhere you keep money. Akatabo never connects to it; you just '
              'pick it when you add.',
              style: t.bodySm.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: 'Name',
              controller: _name,
              textInputAction: TextInputAction.done,
              errorText: _nameError,
              maxLength: 40,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AkSpace.s4),
            const ExcludeSemantics(child: AkEyebrowLabel('Kind')),
            const SizedBox(height: AkSpace.s1h),
            AkSegmented<AccountKind>(
              semanticLabel: 'Kind',
              segments: [for (final (k, label) in newAccountKinds) AkSegment(k, label)],
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: AkSpace.s4),
            const ExcludeSemantics(child: AkEyebrowLabel('Colour')),
            const SizedBox(height: AkSpace.s1h),
            AccountColourChoices(
              selected: _colour,
              onChanged: (token) => setState(() => _pickedColour = token),
            ),
            if (!_editing) ...[
              const SizedBox(height: AkSpace.s4),
              AkTextField(
                label: 'What is in it today, UGX (optional)',
                controller: _opening,
                hint: 'Leave empty to skip',
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsFormatter()],
                figures: true,
              ),
            ],
            const SizedBox(height: AkSpace.s4),
            AkCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SettingsSwitchRow(
                    label: 'Ask for the fee each time',
                    detail: 'Shows the fee box when you pay from here',
                    value: _askFee,
                    divider: true,
                    onChanged: (v) => setState(() => _askFee = v),
                  ),
                  SettingsSwitchRow(
                    label: 'Pick this first when I add',
                    detail: firstNow == null || firstNow.id == _original?.id
                        ? null
                        : 'Now it is ${firstNow.name}',
                    value: _makeDefault,
                    divider: true,
                    onChanged: (v) => setState(() => _makeDefault = v),
                  ),
                  SettingsSwitchRow(
                    label: 'Count it in my totals',
                    detail: 'Switch off for money you hold for someone else',
                    value: _countInTotals,
                    onChanged: (v) => setState(() => _countInTotals = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s6),
            AkPrimaryButton(
              label: _editing ? 'Save changes' : 'Save account',
              onPressed: _saving ? null : _save,
            ),
            if (_problem != null) ...[
              const SizedBox(height: AkSpace.s3),
              Text(_problem!, style: t.bodySm.copyWith(color: c.moneyOut)),
            ],
            if (_editing) ...[
              const SizedBox(height: AkSpace.s3),
              AkOutlineButton(
                label: 'Delete this account',
                ink: c.moneyOut,
                onPressed: _saving ? null : _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The six account colours as 44px discs across the row, as drawn. The chosen disc gets an
/// `ink` ring set off by a gap in the ground colour. A disc whose fill is under 3:1 against
/// the ground (yellow in the light theme) gets a 1px `ink-muted` edge, so every disc stands
/// out in both themes. Each disc is named for screen readers.
class AccountColourChoices extends StatelessWidget {
  const AccountColourChoices({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  /// Whether [token]'s disc needs an edge to stand 3:1 against the ground.
  static bool needsEdge(AkColorTokens c, String token) =>
      contrastRatio(colourForToken(c, token), c.ground) < 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Colour',
      container: true,
      explicitChildNodes: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final token in AccountRepository.accountColourTokens)
            _Disc(
              name: accountColourNames[token]!,
              fill: colourForToken(c, token),
              edge: needsEdge(c, token) ? c.inkMuted : null,
              selected: token == selected,
              onTap: () => onChanged(token),
            ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({
    required this.name,
    required this.fill,
    required this.edge,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color fill;
  final Color? edge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: name,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: AkSize.target,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.ink : c.ground.withValues(alpha: 0),
                  width: AkSize.stroke,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AkSpace.s0h),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: edge == null ? null : Border.all(color: edge!),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
