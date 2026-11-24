import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/seed/default_data.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/forecast.dart';
import '../../domain/spending.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_dashed_box.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_headline_amount.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../budgets/budgets_providers.dart';
import '../budgets/budgets_screen.dart' show BudgetsAtAGlance;
import '../forecast/forecast_providers.dart';
import '../forecast/forecast_words.dart';
import '../settings/home_layout.dart';
import '../transactions/transaction_row.dart';
import 'home_providers.dart';

/// Home: the month so far, where it went, and the latest entries. On the first day, before
/// any entry exists, it shows the three steps to get going instead of empty charts.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(appNowProvider);
    final latestAsync = ref.watch(latestRowsProvider);
    final latest = latestAsync.value ?? const <Transaction>[];
    if (latestAsync.hasValue && latest.isEmpty) return _FirstDay(now: now);

    final monthAsync = ref.watch(monthRowsProvider);
    // A failed load must not read as "Money out UGX 0": say it could not load instead.
    if ((latestAsync.hasError && !latestAsync.hasValue) ||
        (monthAsync.hasError && !monthAsync.hasValue)) {
      return Scaffold(
        backgroundColor: context.colors.ground,
        body: const SafeArea(
          child: Padding(padding: EdgeInsets.all(AkSpace.s6), child: AkEmptyNote(loadFailedText)),
        ),
      );
    }

    final monthName = DateFormat('MMMM').format(now);
    final prevName = DateFormat('MMMM').format(ref.watch(previousSameDaysProvider).start);
    final rows = monthAsync.value ?? const <Transaction>[];
    final previousRows = ref.watch(previousSameDaysRowsProvider).value ?? const <Transaction>[];
    final categories = {
      for (final c in ref.watch(allCategoriesProvider).value ?? const <Category>[]) c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };

    final layout = ref.watch(homeLayoutProvider);
    final totals = totalsOf(rows);
    final previousOut = totalsOf(previousRows).moneyOut;
    final change = percentChange(current: totals.moneyOut, previous: previousOut);
    final parts = moneyOutByCategory(rows);
    final feesAndTax = parts[DefaultIds.fees] ?? 0;
    final budgets = ref.watch(budgetTotalsProvider);
    final daysWithEntries = {for (final t in rows) t.localDay}.length;
    final forecastOn = SettingKeys.forecastMonth.decode(
      ref.watch(storedSettingsProvider).value?[SettingKeys.forecastMonth.name],
    );

    return Scaffold(
      backgroundColor: context.colors.ground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            monthName: monthName,
            caption: 'Money out, 1 to ${now.day} $monthName',
            figure: totals.moneyOut,
            comparison: change == null || previousOut == 0
                ? null
                : change >= 0
                ? '$change% above this point in $prevName'
                : '${-change}% below this point in $prevName',
            tiles: layout.headerTiles
                ? [
                    _StatTile(
                      label: 'Money in',
                      value: formatShort(totals.moneyIn),
                      valueColour: context.colors.moneyInOnBrand,
                    ),
                    // Only once a budget is set: with none, "0 left" would mislead.
                    if (budgets != null)
                      _StatTile(
                        label: budgets.left < 0 ? 'Over budget' : 'Left in budgets',
                        value: formatAmount(budgets.left.abs()),
                        onTap: () => context.go(Routes.budgets),
                        opens: 'Open budgets',
                      ),
                    _StatTile(
                      label: 'Fees and tax',
                      value: formatAmount(feesAndTax),
                      onTap: () => context.push(Routes.fees),
                      opens: 'Open fees and tax',
                    ),
                  ]
                : const [],
          ),
          // The forecast card, as Main.html draws it, once seven days have entries and while
          // "Forecast the month" is on. Its providers are only read once it can show.
          if (layout.forecast && daysWithEntries >= forecastMinDays && forecastOn) ...[
            const SizedBox(height: AkSpace.s3h),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AkSpace.s6),
              child: _ForecastCard(),
            ),
          ],
          if (layout.whereItWent) ...[
            const SizedBox(height: AkSpace.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
              child: _WhereItWent(parts: parts, categories: categories, total: totals.moneyOut),
            ),
          ],
          if (layout.latest) ...[
            const SizedBox(height: AkSpace.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
              child: AkSectionTitle(
                'Latest',
                actionLabel: 'See all',
                onAction: () => context.push(Routes.transactions),
              ),
            ),
            const SizedBox(height: AkSpace.s1),
            for (final tx in latest)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
                child: TransactionRow(
                  transaction: tx,
                  now: now,
                  category: categories[tx.categoryId],
                  accountName: accounts[tx.accountId] ?? '',
                  toAccountName: tx.toAccountId == null ? null : accounts[tx.toAccountId],
                  onTap: () => context.push(Routes.transaction(tx.id)),
                ),
              ),
          ],
          // Draws nothing until a budget is set, so its gap goes inside it.
          if (layout.budgets && budgets != null) ...[
            const SizedBox(height: AkSpace.s5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AkSpace.s6),
              child: BudgetsAtAGlance(),
            ),
          ],
          const SizedBox(height: AkSpace.s6),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.monthName,
    required this.caption,
    required this.figure,
    required this.comparison,
    required this.tiles,
  });

  final String monthName;
  final String caption;
  final int figure;
  final String? comparison;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    // The header sits under the status bar and is the deep main colour in both themes, so the
    // clock and icons above it are light whatever the theme says. `brand-deep` equals `brand`
    // in light; in dark it is the darker fill MainDark.html draws, which keeps the muted
    // caption readable for every main colour.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: c.brandDeep.withValues(alpha: 0)),
      child: Container(
        color: c.brandDeep,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s3, AkSpace.s6, AkSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap, so at a large text size the month moves under the name instead of
                // running off the screen; with room, it sits at the right as drawn.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AkSpace.s3,
                    runSpacing: AkSpace.s2,
                    children: [
                      Text('Akatabo', style: t.displaySm.copyWith(color: c.onBrand)),
                      Semantics(
                        button: true,
                        label: '$monthName, open the calendar',
                        container: true,
                        excludeSemantics: true,
                        onTap: () => context.push(Routes.calendar),
                        // The header is a plain coloured box, so the ripple needs its own
                        // Material to paint on; without it the ink draws under the green.
                        child: Material(
                          type: MaterialType.transparency,
                          // IntrinsicWidth: the centred box would otherwise take the Wrap's
                          // whole width and drop under the name even when there is room.
                          child: InkWell(
                            onTap: () => context.push(Routes.calendar),
                            borderRadius: BorderRadius.circular(context.metrics.pill),
                            child: IntrinsicWidth(
                              child: Container(
                                constraints: const BoxConstraints(minHeight: AkSize.target),
                                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(context.metrics.pill),
                                  border: Border.all(color: c.onBrandMuted),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AkIcon(AkIcons.calendar, color: c.onBrand, size: AkSize.iconSm),
                                    const SizedBox(width: AkSpace.s2),
                                    Text(monthName, style: t.bodyMd.copyWith(color: c.onBrand)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AkSpace.s3h),
                Text(caption, style: t.bodySm.copyWith(color: c.onBrandMuted)),
                const SizedBox(height: AkSpace.s1),
                AkHeadlineAmount(
                  figure,
                  hideable: true,
                  style: t.figureXl.copyWith(color: c.onBrand),
                ),
                if (comparison != null) ...[
                  const SizedBox(height: AkSpace.s1),
                  Text(comparison!, style: t.bodySm.copyWith(color: c.accent)),
                ],
                const SizedBox(height: AkSpace.s4),
                // Side by side and the same height, as drawn, even when one label takes two
                // lines; at a large text size they stack so no figure is squeezed.
                if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, tile) in tiles.indexed) ...[
                        if (i > 0) const SizedBox(height: AkSpace.s2),
                        tile,
                      ],
                    ],
                  )
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, tile) in tiles.indexed) ...[
                          if (i > 0) const SizedBox(width: AkSpace.s2),
                          Expanded(child: tile),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A figure in the header. With [onTap] it opens the page behind it (Budgets, Fees), as
/// Main.html links them; Money in has no page of its own and stays still.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.onTap,
    this.opens,
    this.valueColour,
  });

  final String label;
  final String value;

  /// The figure's colour when it carries a direction (Money in); `on-brand` otherwise.
  final Color? valueColour;
  final VoidCallback? onTap;

  /// The page it opens, for screen readers: "Open budgets".
  final String? opens;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.md);
    final body = Padding(
      padding: const EdgeInsets.all(AkSpace.s2h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.caption.copyWith(color: c.onBrandMuted)),
          const SizedBox(height: AkSpace.s0h),
          AkHiddenAmount(value, style: t.bodyStrong.copyWith(color: valueColour ?? c.onBrand)),
        ],
      ),
    );
    return Material(
      color: c.brandRaised,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              hint: opens,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AkSize.target),
                  child: body,
                ),
              ),
            ),
    );
  }
}

/// "Heading for UGX 1.25M this month" with its likely range, linking to the Forecast screen.
/// Shows nothing until the forecast and its range are ready.
class _ForecastCard extends ConsumerWidget {
  const _ForecastCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final view = ref.watch(monthForecastProvider);
    final forecast = view.forecast;
    final range = view.range;
    if (forecast == null || range == null) return const SizedBox.shrink();

    final today = ref.watch(appNowProvider);
    ref
        .read(forecastSnapshotSaverProvider)
        .remember(
          monthStart: ref.watch(currentMonthProvider).start,
          today: today,
          range: range,
          spentSoFar: forecast.spentSoFar,
        );

    final hidden = ref.watch(amountsHiddenProvider);
    final moneyIn = totalsOf(ref.watch(monthRowsProvider).value ?? const []).moneyIn;
    final gap = forecast.point - moneyIn;
    final title =
        'Heading for UGX ${hidden ? hiddenFigure : formatShort(forecast.point)} this month';
    final subtitle = hidden
        ? 'Likely range hidden'
        : '${rangeInWords(range, formatShort)}. '
              'About ${formatAmount(gap.abs())} ${gap >= 0 ? 'more' : 'less'} than came in';

    return AkCard(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
      semanticLabel: hidden
          ? 'Forecast for this month. $hiddenFigureLabel. Open the forecast'
          : '$title. $subtitle. Open the forecast',
      onTap: () => context.push(Routes.forecast),
      // The card's label says it all once; the texts inside are not read a second time, and
      // hidden figures are never read out as dots.
      child: ExcludeSemantics(
        child: AkListRow(
          leading: AkIconTile(
            icon: AkIcons.trend,
            background: c.surfaceSunk,
            foreground: c.brand,
            size: AkSize.tileSm,
            iconSize: AkSize.iconSm,
          ),
          title: title,
          subtitle: subtitle,
          trailing: AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
        ),
      ),
    );
  }
}

/// The five largest parts of money out, each with its share and a bar relative to the largest.
class _WhereItWent extends StatelessWidget {
  const _WhereItWent({required this.parts, required this.categories, required this.total});

  final Map<String, int> parts;
  final Map<String, Category> categories;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final sorted = parts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AkSectionTitle(
          'Where it went',
          actionLabel: 'See all',
          onAction: () => context.push(Routes.categories),
        ),
        const SizedBox(height: AkSpace.s2),
        if (top.isEmpty)
          Text(
            'Nothing spent this month yet. Add an entry and it appears here.',
            style: t.bodySm.copyWith(color: c.inkMuted),
          )
        else
          for (final e in top)
            _SplitRow(
              category: categories[e.key],
              amount: e.value,
              share: shareOf(e.value, total),
              fraction: e.value / top.first.value,
            ),
      ],
    );
  }
}

class _SplitRow extends ConsumerWidget {
  const _SplitRow({
    required this.category,
    required this.amount,
    required this.share,
    required this.fraction,
  });

  final Category? category;
  final int amount;
  final double share;
  final double fraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final amountText = hidden ? hiddenFigure : formatAmount(amount);
    final name = category?.name ?? 'Other';
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = categoryIconColour(c, category?.colourToken ?? 'cat-slate');
    final shareText = formatPercent(share);

    return Semantics(
      label: '$name, ${hidden ? 'amount hidden' : amountText}, $shareText of money out',
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AkSpace.s2h),
        child: Row(
          children: [
            AkIconTile(
              icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
              background: colour,
              foreground: ink,
              size: AkSize.tileSm,
            ),
            const SizedBox(width: AkSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySm.copyWith(color: c.ink),
                        ),
                      ),
                      Text(amountText, style: t.figure.copyWith(color: c.ink)),
                      const SizedBox(width: AkSpace.s1),
                      Text(shareText, style: t.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s1),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AkSize.bar),
                    child: Stack(
                      children: [
                        Container(height: AkSize.bar, color: c.line),
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0, 1),
                          child: Container(height: AkSize.bar, color: colour),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first day: no entry exists, so the screen says what to do next.
class _FirstDay extends ConsumerWidget {
  const _FirstDay({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final monthName = DateFormat('MMMM').format(now);
    final visible = (ref.watch(allCategoriesProvider).value ?? const <Category>[])
        .where((cat) => !cat.isSystem)
        .length;

    return Scaffold(
      backgroundColor: c.ground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            monthName: monthName,
            caption: 'Money out this month',
            figure: 0,
            comparison: null,
            tiles: const [],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing added yet. Your totals build up here.',
                  style: t.bodySm.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: AkSpace.s4),
                Text('Three steps to get going', style: t.title.copyWith(color: c.ink)),
                const SizedBox(height: AkSpace.s2),
                AkCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _StepRow(
                        number: 1,
                        done: false,
                        title: 'Add something you spent today',
                        detail: 'An amount and a few words is enough',
                        onTap: () => context.push(Routes.add),
                      ),
                      _StepRow(
                        number: 2,
                        done: false,
                        title: 'Check your categories',
                        detail: visible == 0
                            ? 'Your categories will appear here'
                            : '$visible are ready. Rename, recolour or add your own later',
                        // Its words ask the person to check them, so it opens them, like the
                        // other two steps.
                        onTap: () => context.push('${Routes.settingsCategories}?from=home'),
                      ),
                      _StepRow(
                        number: 3,
                        done: false,
                        title: 'Set one budget',
                        detail: 'Start with the category you worry about most',
                        onTap: () => context.go(Routes.budgets),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AkSpace.s5),
                // Dashed, as HomeEmpty.html draws it: the charts have not happened yet.
                AkDashedBox(
                  color: c.inkMuted,
                  radius: context.metrics.lg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AkSpace.s4,
                      vertical: AkSpace.s5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: AkIcon(AkIcons.trend, color: c.inkMuted, size: AkSize.iconLg),
                        ),
                        const SizedBox(height: AkSpace.s2),
                        Text(
                          'Charts and the forecast appear after a few days',
                          textAlign: TextAlign.center,
                          style: t.bodyStrong.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: AkSpace.s1),
                        Text(
                          'Akatabo needs about a week of entries before it can show where your month is heading.',
                          textAlign: TextAlign.center,
                          style: t.bodySm.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AkSpace.s3),
                _FirstDayLink(
                  icon: AkIcons.upload,
                  title: 'Used Akatabo before?',
                  detail: 'Restore your backup file',
                  onTap: () => context.push('${Routes.dataRestore}?from=home'),
                ),
                const SizedBox(height: AkSpace.s3),
                _FirstDayLink(
                  icon: AkIcons.repeat,
                  title: 'Pay something every month?',
                  detail: 'Add rent, fees or bundles once, and they show up as they come due',
                  onTap: () => context.push('${Routes.regularNew}?from=home'),
                ),
                const SizedBox(height: AkSpace.s6),
                Semantics(
                  header: true,
                  child: Text('What Akatabo does', style: t.title.copyWith(color: c.ink)),
                ),
                const SizedBox(height: AkSpace.s3),
                // The three promises from Welcome.html, kept in reach after the welcome.
                for (final (icon, line) in const [
                  (AkIcons.plus, 'Type an amount and a few words. The category fills itself in.'),
                  (AkIcons.chip, 'It forecasts your month and warns you before a budget runs out.'),
                  (
                    AkIcons.lock,
                    'Everything stays on this phone. No account, no adverts, no permissions.',
                  ),
                ]) ...[
                  Row(
                    children: [
                      AkIconTile(
                        icon: icon,
                        background: c.surfaceSunk,
                        foreground: c.brandText,
                        size: AkSize.tileSm,
                      ),
                      const SizedBox(width: AkSpace.s3),
                      Expanded(
                        child: Text(line, style: t.bodySm.copyWith(color: c.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s3),
                ],
                const SizedBox(height: AkSpace.s5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card-sized link on the first day, as HomeEmpty.html draws the restore row.
class _FirstDayLink extends StatelessWidget {
  const _FirstDayLink({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final AkIcons icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '$title $detail',
      onTap: onTap,
      child: AkCard(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
        onTap: onTap,
        child: AkListRow(
          minHeight: AkSize.row + AkSpace.s1,
          titleWeight: FontWeight.w600,
          leading: AkIconTile(
            icon: icon,
            background: c.surfaceSunk,
            foreground: c.brandText,
            size: AkSize.tileSm,
          ),
          title: title,
          subtitle: detail,
          trailing: AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.done,
    required this.title,
    required this.detail,
    this.onTap,
    this.last = false,
  });

  final int number;
  final bool done;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final isFirst = number == 1;
    return Semantics(
      button: onTap != null,
      label: '$title. $detail',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AkSize.row + AkSpace.s2),
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: last ? c.surfaceSunk.withValues(alpha: 0) : c.line),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AkSize.tileSm,
                height: AkSize.tileSm,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? c.brand : c.surfaceSunk.withValues(alpha: 0),
                  border: Border.all(color: isFirst ? c.brand : c.lineStrong, width: 2),
                ),
                child: Text(
                  '$number',
                  style: t.captionStrong.copyWith(color: isFirst ? c.onBrand : c.ink),
                ),
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.bodyMd.copyWith(color: c.ink)),
                    Text(detail, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              if (onTap != null) AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
            ],
          ),
        ),
      ),
    );
  }
}
