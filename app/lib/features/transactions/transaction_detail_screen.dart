import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/formats.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/currency.dart';
import '../../domain/spending.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../home/home_providers.dart';
import 'transaction_row.dart';
import 'transactions_providers.dart';
import 'unusual_card.dart';
import 'unusual_providers.dart';

/// One entry: what it was, where and when, what it cost in total, Edit (Add in edit mode),
/// "Add one like this", and a delete that asks first.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final async = ref.watch(transactionByIdProvider(id));
    final tx = async.value;

    if (tx == null) {
      return Scaffold(
        backgroundColor: c.ground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AkSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AkBackLink('Transactions', onTap: () => closeScreen(context)),
                const SizedBox(height: AkSpace.s4),
                if (async.hasValue)
                  Text('This entry has been deleted.', style: t.bodyStrong.copyWith(color: c.ink))
                else if (async.hasError)
                  const AkEmptyNote(loadFailedText),
              ],
            ),
          ),
        ),
      );
    }

    final now = ref.watch(appNowProvider);
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };
    final category = categories[tx.categoryId];
    final isTransfer = tx.direction == Direction.transfer;
    final isMoneyIn = tx.direction == Direction.moneyIn;
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = categoryIconColour(c, category?.colourToken ?? 'cat-slate');

    final words = tx.description.trim();
    final title = words.isNotEmpty
        ? words
        : (isTransfer ? 'Moved money' : (category?.name ?? 'No category'));
    final sign = isTransfer ? '' : (isMoneyIn ? '+ ' : '- ');
    final amountLine = '${sign}UGX ${formatAmount(tx.amount)}';
    final unusual = ref.watch(unusualNoteProvider(tx.id));
    final when = formatDate(tx.occurredAt, ref.watch(dateStyleProvider), words: 'd MMMM yyyy');
    final whenLine =
        '${_capital(dayLabel(tx.occurredAt, now))}, $when, ${clockLabel(tx.occurredAt)}';

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            Row(
              children: [
                Expanded(child: AkBackLink('Transactions', onTap: () => closeScreen(context))),
                AkPillButton(label: 'Edit', onTap: () => context.push(Routes.addEdit(tx.id))),
              ],
            ),
            const SizedBox(height: AkSpace.s5),
            Row(
              children: [
                AkIconTile(
                  icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
                  background: colour,
                  foreground: ink,
                  size: AkSize.tileLg,
                ),
                const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: Text(title, style: t.title.copyWith(color: c.ink)),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            Text(
              amountLine,
              style: t.figureLg.copyWith(
                color: isMoneyIn ? c.moneyIn : (isTransfer ? c.ink : c.moneyOut),
              ),
            ),
            const SizedBox(height: AkSpace.s1),
            // What was paid in another currency, and the rate used, when it was not shillings.
            if (tx.foreignCurrency != null &&
                tx.foreignAmountMinor != null &&
                tx.rateMicros != null) ...[
              Text(
                foreignSummary(tx.foreignCurrency!, tx.foreignAmountMinor!, tx.rateMicros!),
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s1),
            ],
            Text(whenLine, style: t.bodySm.copyWith(color: c.inkMuted)),
            const SizedBox(height: AkSpace.s5),
            if (unusual != null) ...[
              UnusualCard(
                note: unusual,
                categoryName: category?.name ?? 'this category',
                onThisWasMe: () {
                  ref.read(unusualDismissedProvider.notifier).dismiss(tx.id);
                  unawaited(
                    ref
                        .read(transactionRepositoryProvider)
                        .dismissUnusual(tx.id)
                        .catchError(
                          (Object e, StackTrace s) => FlutterError.reportError(
                            FlutterErrorDetails(exception: e, stack: s, library: 'akatabo unusual'),
                          ),
                        ),
                  );
                },
              ),
              const SizedBox(height: AkSpace.s4),
            ],
            AkCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (!isTransfer) _FactRow('Category', category?.name ?? 'No category'),
                  _FactRow(
                    isTransfer ? 'From' : (isMoneyIn ? 'Paid into' : 'Paid from'),
                    accounts[tx.accountId] ?? 'Account',
                  ),
                  if (isTransfer) _FactRow('To', accounts[tx.toAccountId] ?? 'Account'),
                  if (tx.fee > 0) _FactRow('Fee', formatUgx(tx.fee)),
                  if (tx.tax > 0) _FactRow('Tax', formatUgx(tx.tax)),
                  if (tx.fee > 0 || tx.tax > 0)
                    _FactRow('Total cost to you', formatUgx(totalCostOf(tx)), strong: true),
                  if ((tx.note ?? '').trim().isNotEmpty)
                    _FactRow('Note', tx.note!.trim(), last: true)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s5),
            // Side by side, as drawn. At large text sizes they stack, so neither label clips.
            Builder(
              builder: (context) {
                final like = AkOutlineButton(
                  label: 'Add one like this',
                  onPressed: () => context.push(Routes.addLike(tx.id)),
                );
                final delete = _DeleteButton(
                  what: [
                    if (tx.description.trim().isNotEmpty) tx.description.trim(),
                    formatUgx(tx.amount),
                  ].join(', '),
                  onConfirmed: () async {
                    final deleted = await saveOrSay(
                      context,
                      () => ref.read(transactionRepositoryProvider).delete(tx.id),
                      failed:
                          'This entry could not be deleted. It is still in your totals. Try again.',
                    );
                    if (deleted && context.mounted) await closeScreen(context);
                  },
                );
                if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      like,
                      const SizedBox(height: AkSpace.s3),
                      delete,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: like),
                    const SizedBox(width: AkSpace.s3),
                    Expanded(child: delete),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _capital(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value, {this.strong = false, this.last = false});

  final String label;
  final String value;
  final bool strong;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      label: '$label, $value',
      container: true,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AkSize.row),
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: last ? c.surfaceSunk.withValues(alpha: 0) : c.line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: t.bodySm.copyWith(color: c.inkMuted)),
            ),
            const SizedBox(width: AkSpace.s3),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: (strong ? t.bodyStrong : t.bodyMd).copyWith(color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delete is the last row, in `money-out`, and always asks first.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.what, required this.onConfirmed});

  /// The entry in words, so the dialog names what goes, as the other delete dialogs do.
  final String what;
  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    // The same outline button as "Add one like this" beside it, so the pair match in
    // height and border; only the ink says it removes something.
    return Semantics(
      button: true,
      label: 'Delete this entry',
      container: true,
      excludeSemantics: true,
      onTap: () => _confirm(context),
      child: AkOutlineButton(
        label: 'Delete',
        ink: context.colors.moneyOut,
        onPressed: () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('$what is removed from your totals. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: context.type.button.copyWith(color: context.colors.moneyOut),
            ),
          ),
        ],
      ),
    );
    if (yes == true) await onConfirmed();
  }
}
