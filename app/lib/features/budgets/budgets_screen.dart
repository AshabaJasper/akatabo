import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/seed/default_data.dart';
import '../../domain/budget.dart';
import '../../domain/spending.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_surfaces.dart';
import '../home/home_providers.dart';
import 'budgets_providers.dart';

/// Budgets for this month: what is left overall, what each day allows, and each budget's
/// place against the day of the month. The first tab's money page.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    // The day of the budget month, which differs from the calendar day when "Month starts
    // on" is not the 1st.
    final day = calc.elapsedDays(month, today);
    final rowsAsync = ref.watch(monthRowsProvider);
    final previousAsync = ref.watch(previousMonthRowsProvider);
    final catsAsync = ref.watch(allCategoriesProvider);
    final ready = rowsAsync.hasValue && previousAsync.hasValue && catsAsync.hasValue;
    final failed = rowsAsync.hasError || previousAsync.hasError || catsAsync.hasError;

    final spentNow = moneyOutByCategory(rowsAsync.value ?? const <Transaction>[]);
    final cats = catsAsync.value ?? const <Category>[];
    final names = {for (final cat in cats) cat.id: cat};

    // The same lines Home's "Left in budgets" tile sums, so the two never disagree.
    final lines = [
      for (final l in ref.watch(budgetLinesProvider) ?? const [])
        _lineFor(
          l.category,
          spent: l.spent,
          budget: l.budget,
          day: day,
          daysInMonth: month.lengthInDays,
        ),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));

    final totals = budgetTotalsOf([for (final l in lines) (budget: l.budget, spent: l.spent)]);
    final daysLeft = daysBetween(today, month.end) - 1;
    final pace = budgetPace(day: day, daysInMonth: month.lengthInDays);
    final budgeted = {for (final l in lines) l.category.id};

    // The biggest spend with no budget, offered as "Set one". Fees and tax are not budgeted.
    final unbudgeted = [
      for (final e in spentNow.entries)
        if (!budgeted.contains(e.key) && e.key != DefaultIds.fees && e.value > 0) e,
    ]..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            Semantics(
              header: true,
              child: Text('Budgets', style: t.displayLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s4),
            if (failed)
              const AkEmptyNote('Budgets could not load. Close Akatabo and open it again.')
            else if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (lines.isEmpty && unbudgeted.isEmpty)
              _NoBudgetsYet(
                categories: [
                  for (final cat in cats)
                    if (!cat.isSystem && !cat.hidden && cat.kind == CategoryKind.spending) cat,
                ],
              )
            else ...[
              if (lines.isNotEmpty) ...[
                _Summary(month: month, totals: totals, daysLeft: daysLeft, pace: pace),
                const SizedBox(height: AkSpace.s5),
              ],
              for (final l in lines)
                _BudgetRow(
                  line: l,
                  pace: pace,
                  onTap: () => context.push(Routes.budget(l.category.id)),
                ),
              if (unbudgeted.isNotEmpty) ...[
                const SizedBox(height: AkSpace.s4),
                _Unbudgeted(
                  name: names[unbudgeted.first.key]?.name ?? 'Other',
                  amount: unbudgeted.first.value,
                  onSet: () => context.push(Routes.budget(unbudgeted.first.key)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Home's "Budgets at a glance": the three most used budgets, drawn as on Budgets, with "See
/// all" to the tab. Nothing at all while loading or with no budget set.
class BudgetsAtAGlance extends ConsumerWidget {
  const BudgetsAtAGlance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(budgetLinesProvider);
    if (source == null || source.isEmpty) return const SizedBox.shrink();
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    final day = calc.elapsedDays(month, today);
    final lines = [
      for (final l in source)
        _lineFor(
          l.category,
          spent: l.spent,
          budget: l.budget,
          day: day,
          daysInMonth: month.lengthInDays,
        ),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));
    final pace = budgetPace(day: day, daysInMonth: month.lengthInDays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkSectionTitle(
          'Budgets',
          actionLabel: 'See all',
          onAction: () => context.go(Routes.budgets),
        ),
        const SizedBox(height: AkSpace.s2),
        for (final l in lines.take(3))
          _BudgetRow(line: l, pace: pace, onTap: () => context.push(Routes.budget(l.category.id))),
      ],
    );
  }
}

BudgetLine _lineFor(
  Category cat, {
  required int spent,
  required int budget,
  required int day,
  required int daysInMonth,
}) => BudgetLine(
  category: cat,
  spent: spent,
  budget: budget,
  status: budgetStatus(
    spent: spent,
    budget: budget,
    warnAt: cat.budgetWarnAt,
    day: day,
    daysInMonth: daysInMonth,
  ),
);

/// One budget, as this month sees it.
class BudgetLine {
  const BudgetLine({
    required this.category,
    required this.spent,
    required this.budget,
    required this.status,
  });

  final Category category;
  final int spent;

  /// The budget for this month, with any carry-over.
  final int budget;
  final BudgetStatus status;

  /// Spent over budget, for ordering the rows: the most used first.
  double get ratio => spent / budget;
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.month,
    required this.totals,
    required this.daysLeft,
    required this.pace,
  });

  final Period month;
  final BudgetTotals totals;
  final int daysLeft;
  final double pace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final over = totals.left < 0;
    final name = DateFormat('MMMM').format(month.start);
    final allowance = allowancePerDay(
      budget: totals.budget,
      spent: totals.spent,
      daysLeft: daysLeft,
    );
    return Semantics(
      container: true,
      // "Hide amounts": the card says no figure aloud until one is shown.
      button: hidden ? true : null,
      onTap: hidden ? () => ref.read(amountsRevealedProvider.notifier).reveal() : null,
      label: hidden
          ? '${over ? 'Over budget in $name' : 'Left to spend in $name'}. $hiddenFigureLabel.'
          : '${over ? 'Over budget overall by ${formatUgx(-totals.left)}' : 'Left to spend in $name, ${formatUgx(totals.left)}'}. '
                '${daysLeft == 0 ? '${formatAmount(allowance)} left for today' : '${formatAmount(allowance)} a day for $daysLeft days'}. '
                '${formatAmount(totals.spent)} of ${formatAmount(totals.budget)} spent.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              over ? 'Over budget in $name' : 'Left to spend in $name',
              style: t.bodySm.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AkSpace.s1),
            AkHiddenAmount(
              over ? formatUgx(-totals.left) : formatUgx(totals.left),
              style: t.figureXl.copyWith(color: over ? c.moneyOut : c.ink),
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    daysLeft == 0 ? 'Left for today' : 'A day, for $daysLeft days',
                    style: t.bodySm.copyWith(color: c.inkMuted),
                  ),
                ),
                AkHiddenAmount(formatAmount(allowance), style: t.figure.copyWith(color: c.ink)),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            BudgetBar(
              spent: totals.spent,
              budget: totals.budget,
              pace: pace,
              colour: c.brand,
              over: over,
            ),
            const SizedBox(height: AkSpace.s1),
            Text(
              hidden
                  ? '$hiddenFigure of $hiddenFigure spent'
                  : '${formatAmount(totals.spent)} of ${formatAmount(totals.budget)} spent',
              style: t.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.line, required this.pace, required this.onTap});

  final BudgetLine line;
  final double pace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final cat = line.category;
    final colour = colourForToken(c, cat.colourToken);
    final ink = categoryIconColour(c, cat.colourToken);
    final over = line.status == BudgetStatus.over;
    final word = switch (line.status) {
      BudgetStatus.over => 'Over by ${formatAmount(line.spent - line.budget)}',
      BudgetStatus.nearlyUsed => 'Nearly used',
      BudgetStatus.aLittleAhead => 'A little ahead',
      BudgetStatus.onTrack => 'On track',
    };
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          '${cat.name}, ${formatAmount(line.spent)} of ${formatAmount(line.budget)}. $word. '
          'Tap to change this budget.',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkIconTile(
                icon: AkIcons.fromKey(cat.iconKey),
                background: colour,
                foreground: ink,
                size: AkSize.tileSm,
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(color: c.ink),
                          ),
                        ),
                        Text(
                          '${formatAmount(line.spent)} of ${formatAmount(line.budget)}',
                          style: t.figure.copyWith(color: c.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: AkSpace.s1),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusChip(word: word, over: over),
                    ),
                    const SizedBox(height: AkSpace.s2),
                    BudgetBar(
                      spent: line.spent,
                      budget: line.budget,
                      pace: pace,
                      colour: colour,
                      over: over,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AkSpace.s2),
              AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status in words, on a quiet pill. Over is the only state drawn in `money-out`.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.word, required this.over});

  final String word;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: over ? c.moneyOutSoft : c.surfaceSunk,
        borderRadius: BorderRadius.circular(AkRadiusTokens.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: AkSpace.s1),
        child: Text(word, style: t.captionStrong.copyWith(color: over ? c.moneyOut : c.inkMuted)),
      ),
    );
  }
}

/// A budget bar: the spend as a fill over a `line` track, with a 2px `ink` tick where the
/// spending should be today. Over budget is `money-out` on `money-out-soft`.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.spent,
    required this.budget,
    required this.pace,
    required this.colour,
    required this.over,
  });

  final int spent;
  final int budget;
  final double pace;
  final Color colour;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fraction = budget <= 0 ? 0.0 : (spent / budget).clamp(0, 1).toDouble();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final tickLeft = (width * pace - AkSize.stroke / 2).clamp(0, width - AkSize.stroke);
        return SizedBox(
          height: AkSize.bar + AkSpace.s2,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: AkSize.bar,
                decoration: BoxDecoration(
                  color: over ? c.moneyOutSoft : c.line,
                  borderRadius: BorderRadius.circular(AkRadiusTokens.sm),
                ),
              ),
              Container(
                width: width * fraction,
                height: AkSize.bar,
                decoration: BoxDecoration(
                  color: over ? c.moneyOut : colour,
                  borderRadius: BorderRadius.circular(AkRadiusTokens.sm),
                ),
              ),
              Positioned(
                left: tickLeft.toDouble(),
                top: 0,
                bottom: 0,
                child: Container(width: AkSize.stroke, color: c.ink),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// No budget and no spending yet: the sentence, then every spending category with a way
/// straight into its Set a budget screen, so the tab is never a lone line on an empty page.
class _NoBudgetsYet extends StatelessWidget {
  const _NoBudgetsYet({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No budgets yet. Set one for a category you want to keep an eye on, and it shows '
          'here.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s4),
          AkCard(
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
            child: Column(
              children: [
                for (final (i, cat) in categories.indexed)
                  Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: 'Set a budget for ${cat.name}',
                    onTap: () => context.push(Routes.budget(cat.id)),
                    child: AkListRow(
                      divider: i < categories.length - 1,
                      leading: AkIconTile(
                        icon: AkIcons.fromKey(cat.iconKey),
                        background: colourForToken(c, cat.colourToken),
                        foreground: categoryIconColour(c, cat.colourToken),
                        size: AkSize.tileSm,
                      ),
                      title: cat.name,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Set a budget',
                            style: t.bodySm.copyWith(
                              color: c.brandText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AkSpace.s1),
                          AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
                        ],
                      ),
                      onTap: () => context.push(Routes.budget(cat.id)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Unbudgeted extends StatelessWidget {
  const _Unbudgeted({required this.name, required this.amount, required this.onSet});

  final String name;
  final int amount;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name has no budget', style: t.bodyStrong.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s1),
              Text(
                'You spent ${formatAmount(amount)} on it this month',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        AkTextLink('Set one', onTap: onSet),
      ],
    );
  }
}
