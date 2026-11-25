import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/seed/default_data.dart';
import '../../domain/goals.dart';
import '../../domain/period_summary.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/category_split_row.dart';
import '../budgets/budgets_screen.dart' show GoalsView, openGoalsTab;
import '../goals/goals_providers.dart';
import '../home/home_providers.dart';
import 'calendar_providers.dart';

/// Where a category row leads. Fees and tax sit on other entries, so they have their own
/// page; the plain category page would show nothing for them.
String categoryRoute(String id) => id == DefaultIds.fees ? Routes.fees : Routes.category(id);

/// "this week", "this month": the period in a sentence.
String _thisUnit(PeriodKind kind) => switch (kind) {
  PeriodKind.day => 'on this day',
  PeriodKind.week => 'this week',
  PeriodKind.month => 'this month',
  PeriodKind.quarter => 'in these three months',
  PeriodKind.year => 'this year',
  PeriodKind.custom => 'in these dates',
};

/// What the period before is called in a sentence. While [period] is still running only its
/// first days are compared, so the words say "the same days".
String againstText(Period period, Period previous, {required bool partial}) {
  final month = DateFormat('MMMM').format(previous.start);
  final year = '${previous.start.year}';
  if (!partial) {
    return switch (period.kind) {
      PeriodKind.day => 'the day before',
      PeriodKind.week => 'the week before',
      PeriodKind.month => month,
      PeriodKind.quarter => 'the three months before',
      PeriodKind.year => year,
      PeriodKind.custom => 'the days before',
    };
  }
  return switch (period.kind) {
    PeriodKind.day => 'the day before',
    PeriodKind.week => 'the same days last week',
    PeriodKind.month => 'the same days of $month',
    PeriodKind.quarter => 'the same days of the three months before',
    PeriodKind.year => 'the same days of $year',
    PeriodKind.custom => 'the days before',
  };
}

/// How the period went, under each Calendar view: money in and out with the change against
/// before, the top categories, and goal money set aside. Figures first, one plain sentence
/// after each. Nothing shows until the period before has loaded, so the cards arrive together.
class PeriodCards extends ConsumerWidget {
  const PeriodCards({super.key, required this.period, required this.rows});

  final Period period;

  /// The period's entries, already loaded by Calendar.
  final List<Transaction> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final partial = period.contains(today);
    // Still running: only its first days so far, against the same days before. Finished:
    // the whole period before, so "than October" counts all 31 days of October.
    final previous = partial ? calc.sameDaysOfPrevious(period, today) : calc.previous(period);
    final previousAsync = ref.watch(calendarRowsProvider(previous));
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final movesAsync = ref.watch(allGoalMovesProvider);
    final moves = movesAsync.value ?? const <GoalMove>[];
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    if (previousAsync.isLoading && !previousAsync.hasValue) return const SizedBox.shrink();

    final summary = summarisePeriod(
      period: period,
      rows: rows,
      previousRows: previousAsync.value ?? const <Transaction>[],
      goalMoves: [for (final m in moves) GoalMoveEntry(amount: m.amount, localDay: m.localDay)],
    );
    final unit = _thisUnit(period.kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // With nothing in or out, the view above already says so ("Nothing spent in this
        // week."), so no money cards repeat it.
        if (!summary.isEmpty) ...[
          _MoneyCard(
            summary: summary,
            partial: partial,
            // A failed read of the days before leaves the comparison out, not a wrong one.
            against: previousAsync.hasError
                ? null
                : againstText(period, previous, partial: partial),
          ),
          if (summary.topCategories.isNotEmpty) ...[
            const SizedBox(height: AkSpace.s3),
            _TopCategories(
              summary: summary,
              categories: categories,
              // A category's page shows this month only, so rows open it only from the
              // current month; elsewhere it would show other figures than the row.
              opens: period == calc.month(today),
            ),
          ],
        ],
        // Only once the moves have loaded: loading or failed is not "nothing set aside".
        if (goals.isNotEmpty && movesAsync.hasValue && !movesAsync.hasError) ...[
          if (!summary.isEmpty) const SizedBox(height: AkSpace.s3),
          _SavingsCard(setAside: summary.setAside, unit: unit),
        ],
      ],
    );
  }
}

/// Money out and in side by side, what that leaves, and the change against before.
class _MoneyCard extends ConsumerWidget {
  const _MoneyCard({required this.summary, required this.partial, required this.against});

  final PeriodSummary summary;
  final bool partial;
  final String? against;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final net = summary.net;
    final gap = hidden ? '' : '${formatUgx(net.abs())} ';
    final soFar = partial ? ' so far' : '';
    final netText = net == 0
        ? 'As much went in as out$soFar.'
        : net > 0
        ? '${gap}more in than out$soFar.'
        : '${gap}more out than in$soFar.';
    final change = summary.change;
    final against = this.against;
    final changeText = against == null
        ? null
        : change == null
        ? 'Nothing went out in $against, so there is nothing to compare with.'
        : change == 0
        ? 'About the same out as $against.'
        // Past three times as much, a percent stops meaning much ("1734% more"); a multiple
        // reads plainly.
        : change >= 200
        ? 'About ${(summary.moneyOut / summary.previousOut).round()} times as much out as '
              '$against.'
        : '${change.abs()}% ${change > 0 ? 'more' : 'less'} out than $against.';

    return AkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Spent and received', style: t.bodyStrong.copyWith(color: c.ink)),
          ),
          const SizedBox(height: AkSpace.s2),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Out',
                  amount: summary.moneyOut,
                  colour: c.moneyOut,
                  hidden: hidden,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'In',
                  amount: summary.moneyIn,
                  colour: c.moneyIn,
                  hidden: hidden,
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text(_capitalise(netText), style: t.bodySm.copyWith(color: c.inkMuted)),
          if (changeText != null) ...[
            const SizedBox(height: AkSpace.s3),
            const Divider(height: 1),
            const SizedBox(height: AkSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AkIcon(AkIcons.trend, size: AkSize.iconSm, color: c.inkMuted),
                const SizedBox(width: AkSpace.s2),
                Expanded(
                  child: Text(changeText, style: t.bodySm.copyWith(color: c.ink)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.colour,
    required this.hidden,
  });

  final String label;
  final int amount;
  final Color colour;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      container: true,
      label: hidden
          ? '$label, amount hidden'
          : (amount == 0 ? '$label, none' : '$label, ${formatUgx(amount)}'),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.caption.copyWith(color: c.inkMuted)),
          Text(
            // Never a bare zero on Calendar: nothing is "None", in the muted ink.
            hidden ? hiddenFigure : (amount == 0 ? 'None' : formatAmount(amount)),
            style: t.figure.copyWith(color: amount == 0 ? c.inkMuted : colour),
          ),
        ],
      ),
    );
  }
}

/// Up to three categories by money out, each opening its own page.
class _TopCategories extends StatelessWidget {
  const _TopCategories({required this.summary, required this.categories, required this.opens});

  final PeriodSummary summary;
  final Map<String, Category> categories;

  /// Whether each row opens its category's page.
  final bool opens;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final top = summary.topCategories;
    return AkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Top categories', style: t.bodyStrong.copyWith(color: c.ink)),
          ),
          const SizedBox(height: AkSpace.s1),
          for (final e in top)
            CategorySplitRow(
              category: categories[e.key],
              amount: e.value,
              share: shareOf(e.value, summary.moneyOut),
              fraction: e.value / top.first.value,
              onTap: opens ? () => context.push(categoryRoute(e.key)) : null,
            ),
        ],
      ),
    );
  }
}

/// Goal money set aside in the period, net of anything taken back out. Opens Savings.
class _SavingsCard extends ConsumerWidget {
  const _SavingsCard({required this.setAside, required this.unit});

  final int setAside;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final figure = hidden ? hiddenFigure : formatUgx(setAside.abs());
    final text = setAside == 0
        ? 'No money set aside for goals $unit.'
        : setAside > 0
        ? '$figure set aside for goals $unit.'
        : '$figure taken back out of goals $unit.';
    return AkCard(
      onTap: () => openGoalsTab(context, GoalsView.savings),
      semanticLabel: hidden && setAside != 0
          ? 'Savings. Amount hidden. Opens savings goals'
          : 'Savings. $text Opens savings goals',
      child: Row(
        children: [
          AkIcon(AkIcons.wallet, color: c.brandText),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Savings', style: t.bodyStrong.copyWith(color: c.ink)),
                Text(text, style: t.bodySm.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          AkIcon(AkIcons.chevron, size: AkSize.iconSm, color: c.inkMuted),
        ],
      ),
    );
  }
}
