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
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import 'add_providers.dart';
import 'amount_text.dart';

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

  Direction _direction = Direction.moneyOut;
  String? _categoryId;
  String? _fromId;
  String? _toId;
  bool _showMore = false;
  bool _saving = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _amount.dispose();
    _what.dispose();
    _fee.dispose();
    _tax.dispose();
    _note.dispose();
    super.dispose();
  }

  void _chooseDirection(Direction direction) {
    setState(() {
      _direction = direction;
      // Each kind has its own categories, so an earlier pick would not match the grid.
      _categoryId = null;
      if (direction != Direction.transfer) _toId = null;
      _problems = const [];
    });
  }

  Future<void> _save(Account? defaultAccount, List<Account> accounts) async {
    final from = _fromId ?? defaultAccount?.id;
    final to = _toId ?? _otherAccount(accounts, from)?.id;
    // The moment of saving, not the screen's cached "now", which only moves once a day.
    final now = clock.now();
    final isTransfer = _direction == Direction.transfer;
    final isMoneyIn = _direction == Direction.moneyIn;

    final problems = <String>[
      if (from == null) 'Choose an account.',
      ...TransactionDraft(
        direction: _direction,
        amount: parseAmount(_amount.text),
        accountId: from ?? '',
        toAccountId: isTransfer ? to : null,
        categoryId: isTransfer ? null : _categoryId,
        fee: isMoneyIn ? 0 : parseAmount(_fee.text),
        tax: isMoneyIn ? 0 : parseAmount(_tax.text),
        occurredAt: now,
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
    try {
      await ref
          .read(transactionRepositoryProvider)
          .add(
            TransactionDraft(
              direction: _direction,
              amount: parseAmount(_amount.text),
              description: _what.text.trim(),
              categoryId: isTransfer ? null : _categoryId,
              accountId: from!,
              toAccountId: isTransfer ? to : null,
              fee: isMoneyIn ? 0 : parseAmount(_fee.text),
              tax: isMoneyIn ? 0 : parseAmount(_tax.text),
              note: note.isEmpty ? null : note,
              occurredAt: now,
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
    if (mounted) await closeScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final accounts = ref.watch(enabledAccountsProvider).value ?? const <Account>[];
    final defaultAccount = _defaultAccount(accounts);
    final fromId = _fromId ?? defaultAccount?.id;
    final isTransfer = _direction == Direction.transfer;
    final isMoneyIn = _direction == Direction.moneyIn;
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
            if (!isMoneyIn) ...[
              const SizedBox(height: AkSpace.s5),
              AkTextField(
                label: isTransfer ? 'Fee to move it' : 'Fee, if any',
                controller: _fee,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsFormatter()],
              ),
            ],
            const SizedBox(height: AkSpace.s4),
            AkTextLink(
              _showMore ? 'Fewer details' : 'More details',
              onTap: () => setState(() => _showMore = !_showMore),
            ),
            if (_showMore) ...[
              const SizedBox(height: AkSpace.s4),
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
            const AkEyebrowLabel('When'),
            const SizedBox(height: AkSpace.s1),
            Text(_whenLabel(now), style: t.bodyStrong.copyWith(color: c.ink)),
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

  Account? _defaultAccount(List<Account> accounts) {
    for (final a in accounts) {
      if (a.isDefault) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Account? _otherAccount(List<Account> accounts, String? not) {
    for (final a in accounts) {
      if (a.id != not) return a;
    }
    return null;
  }

  /// "Today, 09:14": the moment the entry is saved. Choosing another time comes with the
  /// date and time picker, which is built in a later phase.
  String _whenLabel(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Today, ${two(now.hour)}:${two(now.minute)}';
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
    final foreground = ThemeData.estimateBrightnessForColor(colour) == Brightness.light
        ? c.ink
        : c.onBrand;
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
