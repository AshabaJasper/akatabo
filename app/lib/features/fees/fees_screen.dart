import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart' show previousMonths;
import '../../domain/fees.dart';
import '../../domain/spending.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/stacked_bars.dart';
import '../add/add_providers.dart';
import '../budgets/budgets_providers.dart';
import '../categories/categories_screen.dart';
import '../home/home_providers.dart';
import '../insights/insights_text.dart';

/// Fees and tax this month, split into sending, withdrawing and tax, and by the account they
/// were paid from. Each figure is worked out from the fee and tax fields; none is typed in.
class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    final rowsAsync = ref.watch(monthRowsProvider);
    final beforeAsync = ref.watch(previousSameDaysRowsProvider);
    final accountsAsync = ref.watch(allAccountsProvider);
    final ready = rowsAsync.hasValue && beforeAsync.hasValue && accountsAsync.hasValue;

    final accounts = accountsAsync.value ?? const <Account>[];
    final names = {for (final a in accounts) a.id: a.name};
    final cashIds = {
      for (final a in accounts)
        if (a.kind == AccountKind.cash) a.id,
    };
    final rows = rowsAsync.value ?? const <Transaction>[];
    final split = feeSplitOf(rows, cashAccountIds: cashIds);
    final previous = feeSplitOf(
      beforeAsync.value ?? const <Transaction>[],
      cashAccountIds: cashIds,
    );
    final spent = totalsOf(rows).moneyOut;
    final against = DateFormat('MMMM').format(calc.previous(month).start);
    final hidden = ref.watch(amountsHiddenProvider);
    // Five months before this one and this one, oldest first. Until the older months load,
    // the chart waits; the rest of the page does not.
    final months = [...previousMonths(calc, month, count: 5), month];
    final older = ref.watch(budgetHistoryRowsProvider).value;
    final history = older == null
        ? null
        : feeSplitsByMonth([...older, ...rows], months: months, cashAccountIds: cashIds);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Insights', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s2),
            Semantics(
              header: true,
              child: Text('Fees and tax', style: t.displayLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s2),
            if (!ready && [rowsAsync, beforeAsync, accountsAsync].any((a) => a.hasError))
              const AkEmptyNote(loadFailedText)
            else if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (split.total == 0)
              AkEmptyNote(
                'No fees or tax this month. They appear here when an entry has one.',
                actionLabel: 'Add a transaction',
                onAction: () => context.push(Routes.add),
              )
            else ...[
              Text(
                'Transaction costs, ${rangeText(month.start, today)}',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s1),
              Text(formatUgx(split.total), style: t.figureXl.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s1),
              Text(
                '${formatPercent(shareOf(split.total, spent))} of everything you spent',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s1),
              Text(
                comparison(split.total, previous.total, against),
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              if (history != null) ...[
                const SizedBox(height: AkSpace.s4),
                AkCard(
                  child: _SixMonths(months: months, splits: history, hidden: hidden),
                ),
              ],
              const SizedBox(height: AkSpace.s5),
              const AkEyebrow('What you paid for'),
              if (split.sending > 0)
                _PartRow(
                  colour: c.brand,
                  title: 'Sending money',
                  detail:
                      '${split.sendingCount} ${split.sendingCount == 1 ? 'payment' : 'payments'}, '
                      'about ${formatAmount(split.sending ~/ split.sendingCount)} each',
                  amount: split.sending,
                ),
              if (split.withdrawing > 0)
                _PartRow(
                  colour: c.catPink,
                  title: 'Withdrawing cash',
                  detail:
                      '${split.withdrawingCount} '
                      '${split.withdrawingCount == 1 ? 'cash-out' : 'cash-outs'}, '
                      'about ${formatAmount(split.withdrawing ~/ split.withdrawingCount)} each',
                  amount: split.withdrawing,
                ),
              if (split.tax > 0)
                _PartRow(
                  colour: c.catAmber,
                  title: split.taxIsAllFromWithdrawals ? 'Tax on withdrawals' : 'Tax',
                  detail: split.taxOnWithdrawals > 0 && !split.taxIsAllFromWithdrawals
                      ? 'Including ${formatUgx(split.taxOnWithdrawals)} on withdrawals'
                      : split.taxIsAllFromWithdrawals
                      ? 'On withdrawals'
                      : 'On money out',
                  amount: split.tax,
                ),
              if (split.byAccount.isNotEmpty) ...[
                const SizedBox(height: AkSpace.s5),
                const AkEyebrow('By account'),
                for (final e
                    in (split.byAccount.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value))))
                  AkListRow(
                    title: names[e.key] ?? 'Account',
                    trailing: Text(formatAmount(e.value), style: t.figure.copyWith(color: c.ink)),
                    divider: true,
                  ),
              ],
              if (split.withdrawing > 0) ...[
                const SizedBox(height: AkSpace.s5),
                Text(
                  'Cash-outs cost you '
                  '${formatUgx(split.withdrawing + split.taxOnWithdrawals)} '
                  'this month. Paying straight from your wallet, where the shop accepts it, '
                  'avoids both the fee and the tax.',
                  style: t.bodySm.copyWith(color: c.inkMuted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Six months of fees and tax as stacked bars: sending at the bottom, then withdrawing, then
/// tax, as Fees.html draws them. This month's bar says "so far" to a screen reader.
class _SixMonths extends StatelessWidget {
  const _SixMonths({required this.months, required this.splits, required this.hidden});

  final List<Period> months;
  final List<FeeSplit> splits;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spoken = [
      for (final (i, s) in splits.indexed)
        '${DateFormat('MMMM').format(months[i].start)} '
            '${hidden ? hiddenFigureLabel : formatAmount(s.total)}'
            '${i == splits.length - 1 ? ' so far' : ''}',
    ].join(', ');
    return StackedBars(
      parts: [
        StackPart(name: 'Sending', colour: c.brand),
        StackPart(name: 'Withdrawing', colour: c.catPink),
        StackPart(name: 'Tax', colour: c.catAmber),
      ],
      columns: [
        for (final (i, s) in splits.indexed)
          StackColumn(
            values: [s.sending, s.withdrawing, s.tax],
            figure: hidden ? hiddenFigure : formatShort(s.total),
            label: DateFormat('MMM').format(months[i].start),
            current: i == splits.length - 1,
          ),
      ],
      semanticLabel: 'Fees and tax for six months. $spoken.',
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.colour,
    required this.title,
    required this.detail,
    required this.amount,
  });

  /// Its colour in the chart, as a small square beside it.
  final Color colour;
  final String title;
  final String detail;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Row(
        children: [
          Container(
            width: AkSize.dot,
            height: AkSize.dot,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(context.metrics.xs),
            ),
          ),
          const SizedBox(width: AkSpace.s2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong.copyWith(color: c.ink)),
                const SizedBox(height: AkSpace.s1),
                Text(detail, style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          Text(formatAmount(amount), style: t.figure.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
