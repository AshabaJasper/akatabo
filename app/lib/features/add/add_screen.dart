import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../data/settings/remembered_rates.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/currency.dart';
import '../../services/notifications/budget_warning.dart';
import '../../smart/category/category_suggester.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_pickers.dart';
import '../../widgets/ak_surfaces.dart';
import 'add_providers.dart';
import 'amount_text.dart';
import 'category_suggestion_providers.dart';
import 'currency_picker.dart';
import 'suggestion_pill.dart';
import 'when_text.dart';

/// Add a transaction: money out, money in or a move between two of the person's accounts.
///
/// Top to bottom, as the design orders it: the kind, the amount, a few words, the category
/// grid, the account, then the optional fee and the extra details. Only the amount and a
/// category are needed to save (validation comes from [TransactionDraft.problems]).
///
/// With [editId] it edits that entry in place (TransactionDetail.html's Edit); with [likeId]
/// it starts a new entry filled from that one, dated now ("Add one like this").
class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key, this.editId, this.likeId})
    : assert(editId == null || likeId == null, 'Edit or copy, not both');

  final String? editId;
  final String? likeId;

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  final _amount = TextEditingController();

  /// The rate typed for a foreign currency: shillings per one unit.
  final _rate = TextEditingController();

  /// UGX, or the three-letter code of the currency the payment was in.
  String _currency = 'UGX';
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

  /// The form has scrolled under the pinned kind and amount, so a hairline marks the edge.
  bool _formScrolled = false;

  /// The amount field moves between the pinned header and the list when the keyboard opens
  /// or closes. The key carries its element across, so the field keeps its focus, cursor and
  /// keyboard instead of being built afresh and grabbing focus again through `autofocus`.
  final _amountKey = GlobalKey(debugLabel: 'amount');
  final _amountFocus = FocusNode(debugLabel: 'amount');
  List<String> _problems = const [];

  /// The entry being edited, once read. Its suggestion is kept on save, so an edit does not
  /// erase what the category suggester learnt from it.
  Transaction? _original;

  /// Editing or copying waits for the entry before the form can be saved.
  bool _filling = false;

  /// The entry could not be read (deleted meanwhile, or the database failed).
  bool _fillFailed = false;

  bool get _editing => widget.editId != null;

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
    final sourceId = widget.editId ?? widget.likeId;
    if (sourceId != null) {
      _filling = true;
      unawaited(_fillFrom(sourceId));
    }
  }

  /// Fills the form from an existing entry. A copy keeps everything but the moment, which
  /// becomes the moment of saving, and starts with nothing to correct.
  Future<void> _fillFrom(String id) async {
    Transaction? tx;
    try {
      tx = await ref.read(transactionRepositoryProvider).byId(id);
    } on Object catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    }
    if (!mounted) return;
    setState(() {
      _filling = false;
      if (tx == null) {
        _fillFailed = true;
        return;
      }
      if (_editing) {
        _original = tx;
        _when = tx.occurredAt;
      }
      _chosenDirection = tx.direction;
      if (tx.foreignCurrency != null && tx.foreignAmountMinor != null && tx.rateMicros != null) {
        _currency = tx.foreignCurrency!;
        _amount.text = foreignFieldText(tx.foreignAmountMinor!);
        _rate.text = formatRate(tx.rateMicros!);
      } else {
        _amount.text = formatAmount(tx.amount);
      }
      _what.text = tx.description;
      _categoryId = tx.categoryId;
      _fromId = tx.accountId;
      _toId = tx.toAccountId;
      if (tx.fee > 0) {
        _fee.text = formatAmount(tx.fee);
        _feeTypedUpFront = true;
      }
      if (tx.tax > 0) _tax.text = formatAmount(tx.tax);
      _note.text = tx.note ?? '';
      _showMore = tx.tax > 0 || (tx.note ?? '').trim().isNotEmpty;
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
    _amountFocus.dispose();
    _amount.dispose();
    _rate.dispose();
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

  Future<void> _save(
    Account? defaultAccount,
    List<Account> accounts,
    CategorySuggestion? suggestion,
  ) async {
    final from = _fromId ?? defaultAccount?.id;
    // The tile the person tapped, or else the suggested one, which the grid shows as chosen.
    final categoryId = _categoryId ?? suggestion?.categoryId;
    final to = _toId ?? _otherAccount(accounts, from)?.id;
    // The chosen moment, or else the moment of saving (not the screen's cached "now", which
    // only moves once a day).
    final now = clock.now();
    final occurredAt = _when ?? now;
    final direction = _direction;
    final isTransfer = direction == Direction.transfer;
    final isMoneyIn = direction == Direction.moneyIn;

    final foreignIncomplete = _foreign && (_foreignMinor == null || _rateMicros == null);
    final problems = <String>[
      if (from == null) 'Choose an account.',
      if (occurredAt.isAfter(now)) 'That time has not come yet. Choose a time up to now.',
      if (foreignIncomplete) 'Enter the $_currency amount and its rate.',
      // A foreign entry that is incomplete is reported above, not as a zero amount.
      ...TransactionDraft(
        direction: direction,
        amount: _shillings(),
        accountId: from ?? '',
        toAccountId: isTransfer ? to : null,
        categoryId: isTransfer ? null : categoryId,
        fee: isMoneyIn ? 0 : parseAmount(_fee.text),
        tax: isMoneyIn ? 0 : parseAmount(_tax.text),
        occurredAt: occurredAt,
      ).problems().where((p) => !(foreignIncomplete && p == 'Enter an amount above zero.')),
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
    final original = _original;
    final draft = TransactionDraft(
      direction: direction,
      amount: _shillings(),
      description: _what.text.trim(),
      categoryId: isTransfer ? null : categoryId,
      accountId: from!,
      toAccountId: isTransfer ? to : null,
      fee: isMoneyIn ? 0 : parseAmount(_fee.text),
      tax: isMoneyIn ? 0 : parseAmount(_tax.text),
      note: note.isEmpty ? null : note,
      occurredAt: occurredAt,
      // What was suggested, so a different pick is stored as a correction. An edit keeps
      // the suggestion made when the entry was first added.
      suggestedCategoryId: isTransfer
          ? null
          : (original != null ? original.suggestedCategoryId : suggestion?.categoryId),
      suggestionConfidence: isTransfer
          ? null
          : (original != null ? original.suggestionConfidence : suggestion?.probability),
      foreignCurrency: _foreign ? _currency : null,
      foreignAmountMinor: _foreign ? _foreignMinor : null,
      rateMicros: _foreign ? _rateMicros : null,
    );
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (original != null) {
        await repo.update(original.id, draft);
        savedId = original.id;
      } else {
        savedId = await repo.add(draft);
      }
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
    // The rate typed becomes the one remembered for this currency. Saving an edit that keeps
    // an old entry's rate leaves today's remembered rate alone. A failure here does not undo
    // the entry, which is already saved.
    final rate = _rateMicros;
    final rateIsNew =
        original == null || original.rateMicros != rate || original.foreignCurrency != _currency;
    if (_foreign && rate != null && rateIsNew) {
      try {
        await ref.read(settingsRepositoryProvider).write(rateSetting(_currency), '$rate');
      } on Object {
        // The entry is saved; the rate simply is not remembered this time.
      }
    }
    // Runs on after Add closes; it reports its own failures and never undoes the save.
    unawaited(warner.afterSave(savedId, previous: original));
    if (mounted) await closeScreen(context);
  }

  bool get _foreign => _currency != 'UGX';

  /// The foreign amount typed, in hundredths, or null while it is not a valid amount.
  int? get _foreignMinor => parseForeignMinor(_amount.text);

  /// The rate typed, in micros, or null while it is not a valid rate.
  int? get _rateMicros => parseRateMicros(_rate.text);

  /// The shillings this entry comes to: the amount typed, or for a foreign payment its
  /// conversion at the rate typed. Zero while a foreign entry is incomplete.
  int _shillings() {
    if (!_foreign) return parseAmount(_amount.text);
    final minor = _foreignMinor;
    final rate = _rateMicros;
    if (minor == null || rate == null) return 0;
    return ugxFor(foreignMinor: minor, rateMicros: rate);
  }

  /// Changes the currency. Each foreign currency starts with the rate remembered for it, or
  /// an empty rate: never the rate of the currency chosen before. Going back to shillings
  /// puts the converted amount in the field when amount and rate are complete, and otherwise
  /// keeps the whole part typed.
  Future<void> _chooseCurrency() async {
    final picked = await pickCurrency(context, current: _currency);
    if (picked == null || picked == _currency || !mounted) return;
    final remembered = rememberedRates(ref.read(storedSettingsProvider).value ?? const {});
    setState(() {
      if (picked == 'UGX') {
        final converted = _shillings();
        final whole = _amount.text.split('.').first;
        _amount.text = converted > 0
            ? formatAmount(converted)
            : (whole.isEmpty ? '' : formatAmount(parseAmount(whole)));
      } else {
        final rate = remembered[picked];
        _rate.text = rate == null ? '' : formatRate(rate);
      }
      _currency = picked;
    });
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
    // waits under "More details" for one that does not. Moving money always shows it, since
    // a fee is the usual cost of moving money. A fee already typed in the form stays there
    // when the account changes, so it never disappears from view.
    final feeUpFront = isTransfer || (from?.askFeeEachTime ?? true) || _feeTypedUpFront;
    final feeField = AkTextField(
      label: isTransfer ? 'Fee to move it' : 'Fee, if any',
      controller: _fee,
      keyboardType: TextInputType.number,
      inputFormatters: const [NoDecimalPointFormatter(), ThousandsFormatter()],
      onChanged: feeUpFront ? (v) => _feeTypedUpFront = v.isNotEmpty : null,
    );
    final categoriesAsync = isMoneyIn
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(spendingCategoriesProvider);
    final offered = categoriesAsync.value ?? const <Category>[];
    // Smart help: a suggestion from the words typed, among the categories on offer. Null
    // when switched off, still loading, too little history or not sure enough.
    final suggester = ref.watch(categorySuggesterProvider);
    final suggestion = isTransfer || suggester == null
        ? null
        : suggester.suggest(
            _what.text,
            amount: _shillings(),
            hour: (_when ?? _shownNow).hour,
            offered: {for (final cat in offered) cat.id},
          );
    final categoryId = _categoryId ?? suggestion?.categoryId;
    Category? suggested;
    for (final cat in offered) {
      if (cat.id == suggestion?.categoryId) suggested = cat;
    }

    final directionRow = Row(
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
    );
    final amountBlock = Column(
      key: _amountKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: AkEyebrowLabel(_foreign ? 'Amount, $_currency' : 'Amount, UGX')),
            // The currency the payment was in. UGX unless the person chooses another.
            AkChip(label: _currency, selected: _foreign, onTap: _chooseCurrency),
          ],
        ),
        const SizedBox(height: AkSpace.s1),
        // Merged, so the name sits on the edit box TalkBack focuses. Without it the box
        // was announced only by its hint, "0" (found on the emulator in Phase 8).
        MergeSemantics(
          child: Semantics(
            label: _foreign ? 'Amount in $_currency' : 'Amount in shillings',
            textField: true,
            child: TextField(
              controller: _amount,
              focusNode: _amountFocus,
              autofocus: true,
              // Shillings are whole, so their keyboard has no decimal key: the shilling
              // formatter would drop a typed point and multiply the amount.
              keyboardType: _foreign
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: _foreign
                  ? const [ForeignAmountFormatter()]
                  : const [NoDecimalPointFormatter(), ThousandsFormatter()],
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
        ),
        if (_foreign) ...[
          const SizedBox(height: AkSpace.s3),
          AkTextField(
            label: 'Rate, UGX for one $_currency',
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ForeignAmountFormatter(decimals: rateDecimals)],
            hint: '3,720',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AkSpace.s2),
          // The live conversion: the shillings this entry is saved as.
          Text(
            _shillings() > 0 ? '= ${ugxLine(_shillings())}' : 'Type the amount and its rate',
            style: t.bodySm.copyWith(color: c.inkMuted),
          ),
        ],
      ],
    );
    // The kind of entry and the amount stay in view while the rest of the form scrolls under
    // them. With very large text, or a short screen once the keyboard is up, pinning both
    // would leave too little room to scroll, so the amount scrolls with the form there.
    final media = MediaQuery.of(context);
    final room = media.size.height - media.padding.vertical - media.viewInsets.bottom;
    final pinAmount = room >= AkSize.pinnedFormMin && media.textScaler.scale(1) <= 1.3;

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              // A hairline appears under the pinned part once the form has scrolled under it.
              decoration: BoxDecoration(
                color: c.ground,
                border: Border(bottom: BorderSide(color: _formScrolled ? c.line : c.ground)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s3, AkSpace.s6, AkSpace.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    directionRow,
                    if (pinAmount) ...[const SizedBox(height: AkSpace.s4), amountBlock],
                  ],
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (n) {
                  final scrolled = n.metrics.pixels > 0;
                  if (scrolled != _formScrolled) setState(() => _formScrolled = scrolled);
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AkSpace.s6,
                    AkSpace.s2,
                    AkSpace.s6,
                    AkSpace.s6,
                  ),
                  children: [
                    if (!pinAmount) ...[amountBlock, const SizedBox(height: AkSpace.s5)],
                    AkTextField(
                      label: isTransfer ? 'What it was for, if anything' : 'What was it for',
                      controller: _what,
                      textInputAction: TextInputAction.done,
                      hint: isTransfer ? null : 'Groceries, Nakasero market',
                      // The suggestion follows the words as they are typed.
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!isTransfer) ...[
                      const SizedBox(height: AkSpace.s5),
                      // The pill sits at the end of the heading row, as drawn; a long category name
                      // moves it to its own line rather than breaking its words. While suggestions
                      // are on, the row keeps the pill's height, so the grid does not jump as the
                      // pill comes and goes during typing.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: suggester == null ? 0 : AkSize.target,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AkSpace.s2,
                              children: [
                                const AkEyebrowLabel('Category'),
                                if (suggestion != null && suggested != null)
                                  SuggestionPill(
                                    categoryName: suggested.name,
                                    probability: suggestion.probability,
                                    selected: categoryId == suggestion.categoryId,
                                    onTap: () => setState(() {
                                      _categoryId = suggestion.categoryId;
                                      _problems = const [];
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AkSpace.s2),
                      categoriesAsync.when(
                        loading: () => const SizedBox(height: AkSize.catCell),
                        error: (_, _) => Text(
                          'Categories could not be loaded. Close this and try again.',
                          style: t.bodySm.copyWith(color: c.moneyOut),
                        ),
                        data: (rows) => LayoutBuilder(
                          builder: (context, box) => GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: _categoryGrid(context, box.maxWidth),
                            children: [
                              for (final cat in rows)
                                _CategoryTile(
                                  category: cat,
                                  selected: cat.id == categoryId,
                                  onTap: () => setState(() {
                                    _categoryId = cat.id;
                                    _problems = const [];
                                  }),
                                ),
                            ],
                          ),
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
                      if (!isMoneyIn && !feeUpFront) ...[
                        feeField,
                        const SizedBox(height: AkSpace.s4),
                      ],
                      if (!isMoneyIn) ...[
                        AkTextField(
                          label: 'Tax, if any',
                          controller: _tax,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [NoDecimalPointFormatter(), ThousandsFormatter()],
                        ),
                        const SizedBox(height: AkSpace.s4),
                      ],
                      AkTextField(
                        label: 'Note',
                        controller: _note,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                    const SizedBox(height: AkSpace.s5),
                    _WhenField(
                      // Unchosen, the entry is stamped when saved, which is always today.
                      label: _when == null
                          ? whenLabel(_shownNow, _shownNow)
                          : whenLabel(_when!, now),
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
                    if (_fillFailed) ...[
                      Text(
                        'That entry could not be opened. It may have been deleted.',
                        style: t.bodySm.copyWith(color: c.moneyOut),
                      ),
                      const SizedBox(height: AkSpace.s3),
                    ],
                    AkPrimaryButton(
                      label: _saving ? 'Saving' : (_editing ? 'Save changes' : 'Save transaction'),
                      // An edit that could not be read must not save a new entry instead.
                      onPressed: _saving || _filling || (_editing && _fillFailed)
                          ? null
                          : () => _save(defaultAccount, accounts, suggestion),
                    ),
                  ],
                ),
              ),
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

/// The category grid: four across as drawn, three at a very large phone text size. Each row
/// is as tall as the drawn tile (width / 0.82) or as tall as the icon plus two lines of the
/// person's text size, whichever is more, so a name never runs out of its tile.
SliverGridDelegate _categoryGrid(BuildContext context, double width) {
  final scaler = MediaQuery.textScalerOf(context);
  final caption = context.type.caption;
  final columns = scaler.scale(1) >= _threeAcrossFrom ? 3 : 4;
  final cell = (width - AkSpace.s2 * (columns - 1)) / columns;
  final line = scaler.scale(caption.fontSize!) * (caption.height ?? 1);
  final needed =
      AkSpace.s1h * 2 + _tileBorder * 2 + AkSize.tileMd + AkSpace.s1 + line * 2 + _roundingRoom;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: AkSpace.s2,
    crossAxisSpacing: AkSpace.s2,
    mainAxisExtent: math.max(cell / _drawnAspect, needed),
  );
}

const _drawnAspect = 0.82;
const _threeAcrossFrom = 1.6;
const _tileBorder = 2.0;
const _roundingRoom = 2.0;

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
              width: _tileBorder,
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
    return Wrap(
      spacing: AkSpace.s2,
      runSpacing: AkSpace.s2,
      children: [
        for (final a in accounts)
          AkChip(
            label: a.name,
            selected: a.id == selectedId,
            dot: accountColour(context, a.colourToken),
            onTap: () => onChanged(a.id),
          ),
      ],
    );
  }
}
