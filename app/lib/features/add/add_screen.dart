import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/notifications/budget_warning.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_pickers.dart';
import '../../widgets/ak_surfaces.dart';
import 'add_providers.dart';
import 'amount_text.dart';
import 'when_text.dart';

/// Add a transaction: money out, money in or a move between two of the person's accounts.
///
/// Top to bottom, as the design orders it: the kind, the amount, a few words, the category
/// grid, the account, then the optional fee and the extra details. Only the amount and a
/// category are needed to save (validation comes from [TransactionDraft.problems]).
class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  final _amount = TextEditingController();
  final _what = TextEditingController();
  final _fee = TextEditingController();
  final _tax = TextEditingController();
  final _note = TextEditingController();

  /// The kind the person tapped; until then, "A new entry starts as" from General settings.
  Direction? _chosenDirection;
  String? _categoryId;
  String? _fromId;
  String? _toId;
  bool _showMore = false;
  bool _saving = false;

  /// A fee was typed while the fee box was in the form, so it stays there.
  bool _feeTypedUpFront = false;
  List<String> _problems = const [];

  /// The time now, for the "When" label until the person chooses a moment. A timer keeps it
  /// to the minute, so Add left open does not show a stale time, or yesterday after midnight.
  late DateTime _shownNow;
  Timer? _tick;

  /// The moment the person chose, or null for "the moment of saving".
  DateTime? _when;
  String? _whenProblem;

  @override
  void initState() {
    super.initState();
    _shownNow = clock.now();
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      final n = clock.now();
      if (n.minute != _shownNow.minute || n.hour != _shownNow.hour || n.day != _shownNow.day) {
        setState(() => _shownNow = n);
      }
    });
  }

  Direction get _direction {
    if (_chosenDirection != null) return _chosenDirection!;
    final stored = ref.read(storedSettingsProvider).value;
    return SettingKeys.newEntryDirection.decode(stored?[SettingKeys.newEntryDirection.name]);
  }

  /// Asks for a day and a time. Days run from [earliestEntryDay] to today; a time later
  /// than now is refused with a message, so an entry is never dated in the future.
  Future<void> _pickWhen() async {
    final now = clock.now();
    final stored = ref.read(storedSettingsProvider).value;
    final weekStartsOn = SettingKeys.weekStartsOn.decode(stored?[SettingKeys.weekStartsOn.name]);
    final picked = await showAkDateTimePicker(
      context,
      initial: _when ?? now,
      first: earliestEntryDay(now),
      last: now,
      dateHelp: 'When was it',
      timeHelp: 'At what time',
      weekStartsOn: weekStartsOn,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.isAfter(clock.now())) {
        _whenProblem = 'That time has not come yet. Choose a time up to now.';
      } else {
        _when = picked;
        _whenProblem = null;
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _amount.dispose();
    _what.dispose();
    _fee.dispose();
    _tax.dispose();
    _note.dispose();
    super.dispose();
  }

  void _chooseDirection(Direction direction) {
    setState(() {
      _chosenDirection = direction;
      // Each kind has its own categories, so an earlier pick would not match the grid.
      _categoryId = null;
      if (direction != Direction.transfer) _toId = null;
      _problems = const [];
    });
  }

  Future<void> _save(Account? defaultAccount, List<Account> accounts) async {
    final from = _fromId ?? defaultAccount?.id;
    final to = _toId ?? _otherAccount(accounts, from)?.id;
    // The chosen moment, or else the moment of saving (not the screen's cached "now", which
    // only moves once a day).
    final now = clock.now();
    final occurredAt = _when ?? now;
    final direction = _direction;
    final isTransfer = direction == Direction.transfer;
    final isMoneyIn = direction == Direction.moneyIn;

    final problems = <String>[
      if (from == null) 'Choose an account.',
      if (occurredAt.isAfter(now)) 'That time has not come yet. Choose a time up to now.',
      ...TransactionDraft(
        direction: direction,
        amount: parseAmount(_amount.text),
        accountId: from ?? '',
        toAccountId: isTransfer ? to : null,
        categoryId: isTransfer ? null : _categoryId,
        fee: isMoneyIn ? 0 : parseAmount(_fee.text),
        tax: isMoneyIn ? 0 : parseAmount(_tax.text),
        occurredAt: occurredAt,
      ).problems(),
    ];
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }

    setState(() {
      _saving = true;
      _problems = const [];
    });
    final note = _note.text.trim();
    // Read before the save: if Add is closed while saving, ref can no longer be used.
    final warner = ref.read(budgetWarnerProvider);
    final String savedId;
    try {
      savedId = await ref
          .read(transactionRepositoryProvider)
          .add(
            TransactionDraft(
              direction: direction,
              amount: parseAmount(_amount.text),
              description: _what.text.trim(),
              categoryId: isTransfer ? null : _categoryId,
              accountId: from!,
              toAccountId: isTransfer ? to : null,
              fee: isMoneyIn ? 0 : parseAmount(_fee.text),
              tax: isMoneyIn ? 0 : parseAmount(_tax.text),
              note: note.isEmpty ? null : note,
              occurredAt: occurredAt,
            ),
          );
    } on Object catch (error, stack) {
      // Keep what the person typed and let them try again; never leave the button stuck.
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      if (mounted) {
        setState(() {
          _saving = false;
          _problems = const ['This entry could not be saved. Try again.'];
        });
      }
      return;
    }
    // Runs on after Add closes; it reports its own failures and never undoes the save.
    unawaited(warner.afterSave(savedId));
    if (mounted) await closeScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    // Rebuild when settings arrive, since the starting kind comes from them.
    ref.watch(storedSettingsProvider);
    final accounts = ref.watch(enabledAccountsProvider).value ?? const <Account>[];
    final defaultAccount = firstPickAccount(accounts);
    final fromId = _fromId ?? defaultAccount?.id;
    final isTransfer = _direction == Direction.transfer;
    final isMoneyIn = _direction == Direction.moneyIn;
    Account? from;
    for (final a in accounts) {
      if (a.id == fromId) from = a;
    }
    // "Ask for the fee each time": the fee box sits in the form for an account that asks, and
    // waits under "More details" for one that does not. A fee already typed in the form stays
    // there when the account changes, so it never disappears from view.
    final feeUpFront = (from?.askFeeEachTime ?? true) || _feeTypedUpFront;
    final feeField = AkTextField(
      label: isTransfer ? 'Fee to move it' : 'Fee, if any',
      controller: _fee,
      keyboardType: TextInputType.number,
      inputFormatters: const [ThousandsFormatter()],
      onChanged: feeUpFront ? (v) => _feeTypedUpFront = v.isNotEmpty : null,
    );
    final categoriesAsync = isMoneyIn
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(spendingCategoriesProvider);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s3, AkSpace.s6, AkSpace.s6),
          children: [
            Row(
              children: [
                _CloseButton(onTap: () => closeScreen(context)),
                const SizedBox(width: AkSpace.s2h),
                Expanded(
                  child: AkSegmented<Direction>(
                    semanticLabel: 'Kind of transaction',
                    selected: _direction,
                    onChanged: _chooseDirection,
                    // Three choices share the row the design drew for two, so the labels go
                    // without icons; with them, each label broke onto two lines.
                    segments: const [
                      AkSegment(Direction.moneyOut, 'Money out'),
                      AkSegment(Direction.moneyIn, 'Money in'),
                      AkSegment(Direction.transfer, 'Move money'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s5),
            const AkEyebrowLabel('Amount, UGX'),
            const SizedBox(height: AkSpace.s1),
            Semantics(
              label: 'Amount in shillings',
              textField: true,
              child: TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsFormatter()],
                style: t.figureXl.copyWith(color: c.ink),
                cursorColor: c.brand,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
                  hintText: '0',
                  hintStyle: t.figureXl.copyWith(color: c.inkMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.brand, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.brand, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AkSpace.s5),
            AkTextField(
              label: isTransfer ? 'What it was for, if anything' : 'What was it for',
              controller: _what,
              textInputAction: TextInputAction.done,
              hint: isTransfer ? null : 'Groceries, Nakasero market',
            ),
            if (!isTransfer) ...[
              const SizedBox(height: AkSpace.s5),
              const AkEyebrowLabel('Category'),
              const SizedBox(height: AkSpace.s2),
              categoriesAsync.when(
                loading: () => const SizedBox(height: AkSize.catCell),
                error: (_, _) => Text(
                  'Categories could not be loaded. Close this and try again.',
                  style: t.bodySm.copyWith(color: c.moneyOut),
                ),
                data: (rows) => GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AkSpace.s2,
                  crossAxisSpacing: AkSpace.s2,
                  childAspectRatio: 0.82,
                  children: [
                    for (final cat in rows)
                      _CategoryTile(
                        category: cat,
                        selected: cat.id == _categoryId,
                        onTap: () => setState(() {
                          _categoryId = cat.id;
                          _problems = const [];
                        }),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AkSpace.s5),
            AkEyebrowLabel(isTransfer ? 'From' : (isMoneyIn ? 'Paid into' : 'Paid from')),
            const SizedBox(height: AkSpace.s2),
            _AccountChoices(
              accounts: accounts,
              selectedId: fromId,
              onChanged: (id) => setState(() => _fromId = id),
            ),
            if (isTransfer) ...[
              const SizedBox(height: AkSpace.s5),
              const AkEyebrowLabel('To'),
              const SizedBox(height: AkSpace.s2),
              _AccountChoices(
                accounts: accounts,
                selectedId: _toId ?? _otherAccount(accounts, fromId)?.id,
                onChanged: (id) => setState(() => _toId = id),
              ),
            ],
            if (!isMoneyIn && feeUpFront) ...[const SizedBox(height: AkSpace.s5), feeField],
            const SizedBox(height: AkSpace.s4),
            AkTextLink(
              _showMore ? 'Fewer details' : 'More details',
              onTap: () => setState(() => _showMore = !_showMore),
            ),
            if (_showMore) ...[
              const SizedBox(height: AkSpace.s4),
              if (!isMoneyIn && !feeUpFront) ...[feeField, const SizedBox(height: AkSpace.s4)],
              if (!isMoneyIn) ...[
                AkTextField(
                  label: 'Tax, if any',
                  controller: _tax,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsFormatter()],
                ),
                const SizedBox(height: AkSpace.s4),
              ],
              AkTextField(label: 'Note', controller: _note, textInputAction: TextInputAction.done),
            ],
            const SizedBox(height: AkSpace.s5),
            _WhenField(
              // Unchosen, the entry is stamped when saved, which is always today.
              label: _when == null ? whenLabel(_shownNow, _shownNow) : whenLabel(_when!, now),
              onTap: _pickWhen,
            ),
            if (_whenProblem != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text(_whenProblem!, style: t.bodySm.copyWith(color: c.moneyOut)),
            ],
            if (_when != null) ...[
              const SizedBox(height: AkSpace.s1),
              AkTextLink(
                'Use the time of saving',
                onTap: () => setState(() {
                  _when = null;
                  _whenProblem = null;
                }),
              ),
            ],
            if (_problems.isNotEmpty) ...[
              const SizedBox(height: AkSpace.s4),
              for (final p in _problems)
                Padding(
                  padding: const EdgeInsets.only(bottom: AkSpace.s1),
                  child: Text(p, style: t.bodySm.copyWith(color: c.moneyOut)),
                ),
            ],
            const SizedBox(height: AkSpace.s5),
            AkPrimaryButton(
              label: _saving ? 'Saving' : 'Save transaction',
              onPressed: _saving ? null : () => _save(defaultAccount, accounts),
            ),
          ],
        ),
      ),
    );
  }

  Account? _otherAccount(List<Account> accounts, String? not) {
    for (final a in accounts) {
      if (a.id != not) return a;
    }
    return null;
  }
}

/// "When", drawn as the design draws it: a 48px field with the moment in it. Tapping it
/// opens the date picker, then the time picker.
class _WhenField extends StatelessWidget {
  const _WhenField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExcludeSemantics(child: AkEyebrowLabel('When')),
        const SizedBox(height: AkSpace.s1h),
        Semantics(
          button: true,
          label: 'When, $label',
          hint: 'Change the day and time',
          container: true,
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: c.lineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: AkSize.input),
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h, vertical: AkSpace.s2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: t.figure.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w500,
                          fontSize: t.bodyMd.fontSize,
                        ),
                      ),
                    ),
                    const SizedBox(width: AkSpace.s2),
                    AkIcon(AkIcons.calendar, color: c.inkMuted, size: AkSize.iconSm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Close',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AkSize.target,
          height: AkSize.target,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.lineStrong),
          ),
          child: AkIcon(AkIcons.close, color: c.ink, size: AkSize.iconSm),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final m = context.metrics;
    final colour = colourForToken(c, category.colourToken);
    // Dark ink on light colours (amber, ochre), white on the rest, so the icon stays readable.
    final foreground = categoryIconColour(c, category.colourToken);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(m.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AkSpace.s1h, horizontal: AkSpace.s0h),
          decoration: BoxDecoration(
            color: selected ? c.surface : c.surfaceSunk.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(m.lg),
            // A 2px border on all four sides; the transparent one keeps the layout still.
            border: Border.all(
              color: selected ? c.brand : c.surfaceSunk.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AkIconTile(
                icon: AkIcons.fromKey(category.iconKey),
                background: colour,
                foreground: foreground,
                size: AkSize.tileMd,
              ),
              const SizedBox(height: AkSpace.s1),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: c.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChoices extends StatelessWidget {
  const _AccountChoices({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AkSpace.s2,
      runSpacing: AkSpace.s2,
      children: [
        for (final a in accounts)
          AkChip(
            label: a.name,
            selected: a.id == selectedId,
            dot: colourForToken(c, a.colourToken),
            onTap: () => onChanged(a.id),
          ),
      ],
    );
  }
}
