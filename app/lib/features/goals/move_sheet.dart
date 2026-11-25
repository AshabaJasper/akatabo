import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/balances.dart';
import '../../services/security/hidden_amounts.dart';
import '../../widgets/ak_controls.dart';
import '../add/add_providers.dart';
import '../add/amount_text.dart';
import '../transactions/transactions_providers.dart';
import 'goal_summary.dart';
import 'goal_widgets.dart';
import 'goals_providers.dart';

/// Opens the sheet that sets money aside for [goal], or takes it back out when [add] is false.
/// Resolves to the milestones the move crossed (empty when none), or null when dismissed.
Future<List<int>?> showGoalMoveSheet(
  BuildContext context, {
  required Goal goal,
  required List<GoalMove> moves,
  required bool add,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _MoveSheet(goal: goal, moves: moves, add: add),
  );
}

class _MoveSheet extends ConsumerStatefulWidget {
  const _MoveSheet({required this.goal, required this.moves, required this.add});

  final Goal goal;
  final List<GoalMove> moves;
  final bool add;

  @override
  ConsumerState<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<_MoveSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _accountId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The over-balance warning follows the amount as it is typed.
    _amount.addListener(_onAmount);
  }

  void _onAmount() => setState(() {});

  @override
  void dispose() {
    _amount.removeListener(_onAmount);
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// This goal's money in each account.
  Map<String, int> get _held => savedByAccount(widget.moves);

  /// Accounts this move can use: the switched-on accounts when adding, and any account
  /// holding this goal's money when taking out, so money in an account switched off since
  /// can still come back.
  List<Account> _choices({required List<Account> enabled, required List<Account> all}) {
    if (widget.add) return enabled;
    final held = _held;
    return [
      for (final a in all)
        if ((held[a.id] ?? 0) > 0) a,
    ];
  }

  /// The account chosen until the person picks one: when adding, the one Add opens on
  /// (Settings > General, "Picked first when you add"), as long as it is offered here.
  String? _startId(List<Account> choices) {
    if (choices.isEmpty) return null;
    if (widget.add) return firstPickAccount(choices)?.id;
    return choices.first.id;
  }

  /// What is free in [account]: its balance less every goal's money set aside in it. Null when
  /// the balance is not known (never set, or the rows have not loaded), so no warning guesses.
  int? _freeIn(
    Account account,
    List<Account> all, {
    required List<Transaction>? rows,
    required List<GoalMove>? allMoves,
  }) {
    if (rows == null || allMoves == null) return null;
    final balance = balancesOf(all, rows).byAccount[account.id];
    if (balance == null) return null;
    return balance - (savedByAccount(allMoves)[account.id] ?? 0);
  }

  Future<void> _save(List<Account> choices, {required bool hidden}) async {
    if (_saving) return;
    final amount = parseAmount(_amount.text);
    final accountId = _accountId ?? _startId(choices);
    if (amount <= 0) {
      setState(() => _error = 'Type an amount above zero.');
      return;
    }
    if (accountId == null) {
      setState(() => _error = 'Nothing is saved for this goal to take out.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final crossed = await ref
          .read(goalRepositoryProvider)
          .addMove(
            goalId: widget.goal.id,
            accountId: accountId,
            amount: widget.add ? amount : -amount,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop(crossed);
    } on ArgumentError {
      // The sheet may have been dragged shut while the write ran.
      if (!mounted) return;
      final account = choices.firstWhere((a) => a.id == accountId);
      setState(() {
        _saving = false;
        _error = widget.add
            ? 'That amount could not be set aside.'
            : 'That is more than this goal has in ${account.name}: '
                  '${shownUgx(_held[accountId] ?? 0, hidden: hidden)}.';
      });
    } on StateError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'This goal cannot take a move right now. Close this and open the goal again.';
      });
    } on Object {
      // Anything else, such as a database error: say so and let the person try again, rather
      // than leave the button switched off for good.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'That could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    // Watched from the start, not only once an amount is typed, so the over-balance warning
    // is ready with the first figure instead of a moment after it.
    final rows = widget.add ? ref.watch(allTransactionsProvider).value : null;
    final allMoves = widget.add ? ref.watch(allGoalMovesProvider).value : null;
    final all = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final enabled = ref.watch(enabledAccountsProvider).value ?? const <Account>[];
    final choices = _choices(enabled: enabled, all: all);
    final selected = _accountId ?? _startId(choices);
    final held = _held;
    final title = widget.add
        ? 'Set aside for ${widget.goal.name}'
        : 'Take out of ${widget.goal.name}';

    String? warning;
    final selectedAccount = [
      for (final a in choices)
        if (a.id == selected) a,
    ].firstOrNull;
    final amount = parseAmount(_amount.text);
    if (widget.add && selectedAccount != null && amount > 0) {
      final free = _freeIn(selectedAccount, all, rows: rows, allMoves: allMoves);
      if (free != null && amount > free) {
        warning =
            'This is more than is free in ${selectedAccount.name} '
            '(${shownUgx(free < 0 ? 0 : free, hidden: hidden)}). You can still set it aside.';
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AkSpace.s6,
        0,
        AkSpace.s6,
        AkSpace.s6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: t.title.copyWith(color: c.ink)),
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: widget.add ? 'Amount, UGX' : 'Amount to take out, UGX',
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              figures: true,
              errorText: _error,
            ),
            if (warning != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text(warning, style: t.caption.copyWith(color: c.inkMuted)),
            ],
            const SizedBox(height: AkSpace.s4),
            if (choices.isEmpty)
              Text(
                widget.add
                    ? 'No account is switched on. Switch one on in Settings first.'
                    : 'No account holds money for this goal yet.',
                style: t.body.copyWith(color: c.inkMuted),
              )
            else ...[
              Text(
                widget.add ? 'From account' : 'Back to account',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s2),
              Wrap(
                spacing: AkSpace.s2,
                runSpacing: AkSpace.s2,
                children: [
                  for (final a in choices)
                    AkChip(
                      label: widget.add
                          ? a.name
                          : '${a.name} · ${shownAmount(held[a.id] ?? 0, hidden: hidden)}',
                      selected: a.id == selected,
                      onTap: () => setState(() => _accountId = a.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: 'Note, optional',
              controller: _note,
              textInputAction: TextInputAction.done,
              maxLength: 60,
            ),
            const SizedBox(height: AkSpace.s5),
            AkPrimaryButton(
              label: widget.add ? 'Set aside' : 'Take out',
              onPressed: _saving || choices.isEmpty ? null : () => _save(choices, hidden: hidden),
            ),
          ],
        ),
      ),
    );
  }
}
