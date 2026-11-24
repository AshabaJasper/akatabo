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
import '../../data/settings/setting_keys.dart';
import '../../domain/forecast.dart';
import '../../domain/insights.dart';
import '../../domain/spending.dart';
import '../../smart/forecast/forecast_range.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_headline_amount.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/cumulative_line.dart';
import '../forecast/forecast_providers.dart';
import '../forecast/forecast_words.dart';
import '../home/home_providers.dart';
import 'insights_providers.dart';
import 'insights_text.dart';

const _kinds = [PeriodKind.week, PeriodKind.month, PeriodKind.quarter, PeriodKind.year];

String _kindLabel(PeriodKind k) => switch (k) {
  PeriodKind.week => 'Week',
  PeriodKind.quarter => '3 months',
  PeriodKind.year => 'Year',
  _ => 'Month',
};

/// Insights: what was spent and how it moved, for the week, month, three months or year.
/// The figures come from the same rules as Home and Calendar; a chart is drawn only once
/// its entries have loaded, so no empty figure flashes before the real one.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  PeriodKind _kind = PeriodKind.month;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final today = dateOnly(now);
    final calc = ref.watch(periodCalculatorProvider);
    final period = calc.of(_kind, today);
    final previous = calc.sameDaysOfPrevious(period, today);

    final current = ref.watch(insightsRowsProvider(period));
    final before = ref.watch(insightsRowsProvider(previous));
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    final ready = current.hasValue && before.hasValue;
    final rows = current.value ?? const <Transaction>[];
    final prevRows = before.value ?? const <Transaction>[];
    final totals = totalsOf(rows);
    final percent = percentChange(current: totals.moneyOut, previous: totalsOf(prevRows).moneyOut);
    final against = againstWord(_kind, previous);
    final changes = categoryChanges(
      current: rows,
      previous: prevRows,
    ).where((ch) => ch.percent != null && ch.change != 0).take(3).toList();

    final lastShown = today.isBefore(period.lastDate) ? today : period.lastDate;
    final colours = CumulativeColours(
      line: c.brand,
      fill: c.brandSoft,
      previous: c.switchOff,
      forecast: c.moneyOut,
      band: c.rangeBand,
      grid: c.line,
    );

    // The forecast card shows only for the current month, and only while Forecast is on.
    final forecastOn = SettingKeys.forecastMonth.decode(
      ref.watch(storedSettingsProvider).value?[SettingKeys.forecastMonth.name],
    );
    final forecastView = ref.watch(monthForecastProvider);
    final showForecast =
        forecastOn &&
        _kind == PeriodKind.month &&
        period.start == ref.watch(currentMonthProvider).start &&
        forecastView.forecast != null;

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
          children: [
            Semantics(
              header: true,
              child: Text('Insights', style: t.displayLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s4),
            AkSegmented<PeriodKind>(
              semanticLabel: 'Period',
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
              segments: [for (final k in _kinds) AkSegment(k, _kindLabel(k))],
            ),
            const SizedBox(height: AkSpace.s5),
            if (!ready && (current.hasError || before.hasError))
              const AkEmptyNote(loadFailedText)
            else if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (rows.isEmpty)
              AkEmptyNote(
                'Nothing spent or received in this period yet.',
                actionLabel: 'Add a transaction',
                onAction: () => context.push(Routes.add),
              )
            else ...[
              Text(
                'Spent, ${rangeText(period.start, lastShown)}',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s1),
              AkHeadlineAmount(
                totals.moneyOut,
                hideable: true,
                style: t.figureXl.copyWith(color: c.ink),
              ),
              const SizedBox(height: AkSpace.s4),
              CumulativeLineChart(
                summary: _chartSummary(totals.moneyOut, percent, against),
                actual: runningTotal(rows, period.start, period.lengthInDays, until: today),
                previous: [
                  for (final v in runningTotal(prevRows, previous.start, previous.lengthInDays))
                    v ?? 0,
                ],
                colours: colours,
                hideFigures: ref.watch(amountsHiddenProvider),
              ),
              const SizedBox(height: AkSpace.s2),
              _Legend(
                thisLabel: _kind == PeriodKind.month
                    ? DateFormat('MMMM').format(period.start)
                    : 'This period',
                againstLabel: against,
              ),
              const SizedBox(height: AkSpace.s2),
              Text(
                comparisonReading(percent, against),
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              if (showForecast) ...[
                const SizedBox(height: AkSpace.s4),
                _ForecastSummary(
                  forecast: forecastView.forecast!,
                  range: forecastView.range,
                  moneyIn: totals.moneyIn,
                  hidden: ref.watch(amountsHiddenProvider),
                  onTap: () => context.push(Routes.forecast),
                ),
              ],
              const SizedBox(height: AkSpace.s5),
              _CashFlow(totals: totals),
              const SizedBox(height: AkSpace.s5),
              if (changes.isNotEmpty) ...[
                const AkEyebrow('Biggest changes'),
                for (final ch in changes)
                  _ChangeRow(
                    change: ch,
                    category: categories[ch.categoryId],
                    onTap: () => context.push(
                      ch.categoryId == DefaultIds.fees
                          ? Routes.fees
                          : Routes.category(ch.categoryId),
                    ),
                  ),
                const SizedBox(height: AkSpace.s4),
              ],
            ],
            const AkEyebrow('Look closer'),
            _LinkRow(
              label: 'Categories',
              dot: c.brand,
              onTap: () => context.push(Routes.categories),
            ),
            _LinkRow(
              label: 'Fees and tax',
              dot: c.moneyOut,
              onTap: () => context.push(Routes.fees),
            ),
            // "Forecast the month" in Smart help switches the forecast off.
            if (SettingKeys.forecastMonth.decode(
              ref.watch(storedSettingsProvider).value?[SettingKeys.forecastMonth.name],
            ))
              _LinkRow(
                label: 'Forecast',
                dot: c.inkMuted,
                onTap: () => context.push(Routes.forecast),
              ),
            _LinkRow(
              label: 'Coming up',
              dot: c.inkMuted,
              onTap: () => context.push(Routes.regular),
            ),
          ],
        ),
      ),
    );
  }

  String _chartSummary(int spent, int? percent, String against) =>
      'Running total of money out'
      '${ref.watch(amountsHiddenProvider) ? '' : ', ${formatUgx(spent)} so far'}. '
      '${comparisonReading(percent, against)}';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.thisLabel, required this.againstLabel});

  final String thisLabel;
  final String againstLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Row(
      children: [
        Container(width: AkSize.dot * 2, height: AkSize.bar, color: c.brand),
        const SizedBox(width: AkSpace.s1h),
        Text(thisLabel, style: t.caption.copyWith(color: c.inkMuted)),
        const SizedBox(width: AkSpace.s3),
        Container(width: AkSize.dot * 2, height: AkSize.stroke, color: c.switchOff),
        const SizedBox(width: AkSpace.s1h),
        Text(againstLabel, style: t.caption.copyWith(color: c.inkMuted)),
      ],
    );
  }
}

/// Money in and money out as two bars, with the net in the heading.
class _CashFlow extends ConsumerWidget {
  const _CashFlow({required this.totals});

  final PeriodTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final largest = [totals.moneyIn, totals.moneyOut].reduce((a, b) => a > b ? a : b);
    final net = totals.net;
    return AkCard(
      semanticLabel: hidden
          ? 'Cash flow: amounts hidden'
          : 'Cash flow: in ${formatUgx(totals.moneyIn)}, out ${formatUgx(totals.moneyOut)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cash flow', style: t.bodyStrong.copyWith(color: c.ink)),
              ),
              // The net figure takes the direction's colour (in when ahead, out when behind),
              // beside its sign; hidden or level, it stays muted.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: hidden ? hiddenFigure : formatSigned(net.abs(), moneyIn: net >= 0),
                      style: t.bodySm.copyWith(
                        color: hidden || net == 0 ? c.inkMuted : (net > 0 ? c.moneyIn : c.moneyOut),
                        fontWeight: hidden || net == 0 ? null : FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' so far'),
                  ],
                ),
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          _FlowBar(
            label: 'In',
            amount: totals.moneyIn,
            largest: largest,
            colour: c.moneyIn,
            hidden: hidden,
          ),
          const SizedBox(height: AkSpace.s2),
          _FlowBar(
            label: 'Out',
            amount: totals.moneyOut,
            largest: largest,
            colour: c.moneyOut,
            hidden: hidden,
          ),
        ],
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  const _FlowBar({
    required this.label,
    required this.amount,
    required this.largest,
    required this.colour,
    required this.hidden,
  });

  final String label;
  final int amount;
  final int largest;
  final Color colour;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final fraction = largest == 0 ? 0.0 : amount / largest;
    return Row(
      children: [
        SizedBox(
          width: AkSize.tileLg,
          child: Text(label, style: t.bodySm.copyWith(color: c.inkMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AkRadiusTokens.sm),
            child: Stack(
              children: [
                Container(height: AkSize.bar, color: c.line),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: AkSize.bar, color: colour),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AkSpace.s3),
        Text(hidden ? hiddenFigure : formatAmount(amount), style: t.figure.copyWith(color: c.ink)),
      ],
    );
  }
}

class _ChangeRow extends ConsumerWidget {
  const _ChangeRow({required this.change, required this.category, required this.onTap});

  final CategoryChange change;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hidden = ref.watch(amountsHiddenProvider);
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = categoryIconColour(c, category?.colourToken ?? 'cat-slate');
    final up = change.change > 0;
    final detail =
        '${up ? 'Up' : 'Down'} ${formatPercent(change.percent!.abs().toDouble())}'
        '${hidden ? '' : ', ${up ? '+' : '-'} ${formatAmount(change.change.abs())}'}';
    return AkListRow(
      leading: AkIconTile(
        icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
        background: colour,
        foreground: ink,
        size: AkSize.tileSm,
      ),
      title: category?.name ?? 'Other',
      subtitle: detail,
      trailing: AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
      onTap: onTap,
      divider: true,
    );
  }
}

/// The month's forecast in one card: the headline, the range and what is safe to spend a day.
/// Tapping it opens the full Forecast page.
class _ForecastSummary extends StatelessWidget {
  const _ForecastSummary({
    required this.forecast,
    required this.range,
    required this.moneyIn,
    required this.hidden,
    required this.onTap,
  });

  final Forecast forecast;
  final ForecastRange? range;
  final int moneyIn;

  /// Amounts are hidden: every figure shows as dots, as the rest of Insights does.
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final m = context.metrics;
    final safe = safeToSpend(
      moneyIn: moneyIn,
      forecastPoint: forecast.point,
      daysLeft: forecast.daysLeft + 1,
    );
    String money(int v) => hidden ? hiddenFigure : formatUgx(v);
    final safeText = switch (safe) {
      SafeAmount(:final perDay) => 'Safe to spend ${money(perDay)} a day',
      OverBy(:final amount) => 'Over by ${money(amount)}',
      null => null,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(m.md),
      child: Container(
        padding: const EdgeInsets.all(AkSpace.s4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(m.md),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Money out by month end', style: t.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: AkSpace.s1),
            Text(money(forecast.point), style: t.figure.copyWith(color: c.ink)),
            if (range != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text(rangeInWords(range!, money), style: t.bodySm.copyWith(color: c.inkMuted)),
            ],
            if (safeText != null) ...[
              const SizedBox(height: AkSpace.s2),
              Text(safeText, style: t.bodyMd.copyWith(color: safe is OverBy ? c.moneyOut : c.ink)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap, this.dot});

  final String label;
  final VoidCallback onTap;

  /// A small coloured dot that tells the rows apart at a glance.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AkListRow(
      leading: dot == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox(width: AkSpace.s2, height: AkSpace.s2),
            ),
      title: label,
      trailing: AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
      onTap: onTap,
      divider: true,
    );
  }
}
