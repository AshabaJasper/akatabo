import 'dart:math' as math;

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
import '../../domain/forecast.dart';
import '../../domain/insights.dart';
import '../../domain/spending.dart';
import '../../smart/forecast/forecast_range.dart';
import '../../widgets/ak_dashed_box.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_headline_amount.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/cumulative_line.dart';
import '../home/home_providers.dart';
import '../settings/settings_page.dart' show ordinalDay;
import 'forecast_providers.dart';
import 'forecast_words.dart';

/// The month-end forecast: where money out is likely to land, how it was worked out, and the
/// running total with the forecast drawn beyond today. It is shown only once seven days this
/// month have entries, so an early guess is never presented as a forecast.
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final month = ref.watch(currentMonthProvider);
    final view = ref.watch(monthForecastProvider);
    final ready = view.ready;
    final forecast = view.forecast;
    final range = view.range;
    final monthRows = ref.watch(monthRowsProvider).value ?? const <Transaction>[];
    final sameDaysLastMonth =
        ref.watch(previousSameDaysRowsProvider).value ?? const <Transaction>[];
    final hidden = ref.watch(amountsHiddenProvider);
    final daysWithEntries = view.daysWithEntries;
    if (forecast != null && range != null) {
      ref
          .read(forecastSnapshotSaverProvider)
          .remember(
            monthStart: month.start,
            today: today,
            range: range,
            spentSoFar: forecast.spentSoFar,
          );
    }
    final ended = DateFormat('d MMMM').format(month.lastDate);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Insights', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s3),
            Semantics(
              header: true,
              child: Text('Forecast: money out by $ended', style: t.titleLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s4),
            if (view.failed)
              const AkEmptyNote(loadFailedText)
            else if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (forecast == null)
              AkEmptyNote(
                'A forecast appears once seven days this month have entries. '
                '${(forecastMinDays - daysWithEntries).clamp(0, forecastMinDays)} more to go.',
                actionLabel: 'Add a transaction',
                onAction: () => context.push(Routes.add),
              )
            else
              _ForecastBody(
                forecast: forecast,
                range: range,
                month: month,
                today: today,
                monthRows: monthRows,
                moneyIn: totalsOf(monthRows).moneyIn,
                lastMonthSpent: totalsOf(sameDaysLastMonth).moneyOut,
                hidden: hidden,
              ),
          ],
        ),
      ),
    );
  }
}

class _ForecastBody extends StatelessWidget {
  const _ForecastBody({
    required this.forecast,
    required this.range,
    required this.month,
    required this.today,
    required this.monthRows,
    required this.moneyIn,
    required this.lastMonthSpent,
    required this.hidden,
  });

  final Forecast forecast;

  /// The range around the forecast; null when "Forecast the month" is off.
  final ForecastRange? range;
  final Period month;
  final DateTime today;
  final List<Transaction> monthRows;
  final int moneyIn;

  /// Money out over the same days last month; zero when there was none to compare with.
  final int lastMonthSpent;

  /// Amounts are hidden: every figure shows as dots.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    String money(int v) => hidden ? hiddenFigure : formatUgx(v);
    final gap = forecast.point - moneyIn;
    // The history the rate comes from: the last 90 days, or fewer for someone new.
    final historyDays = forecast.everydayDaily.isEmpty
        ? rateWindowDays
        : forecast.everydayDaily.length;
    final actual = runningTotal(monthRows, month.start, month.lengthInDays, until: today);

    // From today's total to the point, one step a day, so the dotted line meets the solid one.
    final spent = forecast.spentSoFar.toDouble();
    final path = <double>[
      for (var k = 0; k <= forecast.daysLeft; k++)
        forecast.daysLeft == 0
            ? forecast.point.toDouble()
            : spent + (forecast.point - spent) * k / forecast.daysLeft,
    ];

    final colours = CumulativeColours(
      line: c.brand,
      fill: c.brandSoft,
      previous: c.switchOff,
      forecast: c.moneyOut,
      band: c.rangeBand,
      grid: c.line,
      incomeLine: c.moneyIn,
    );

    // Today counts as one of the days left to share the spare money over.
    final safe = safeToSpend(
      moneyIn: moneyIn,
      forecastPoint: forecast.point,
      daysLeft: forecast.daysLeft + 1,
    );
    final pace = paceVsLast(thisMonth: forecast.spentSoFar, lastMonth: lastMonthSpent);
    final oneOffs = forecast.oneOffs;
    final leftOut = [
      for (final row in monthRows)
        if (oneOffs.contains(row.id)) row,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkHeadlineAmount(forecast.point, hideable: true, style: t.figureXl.copyWith(color: c.ink)),
        const SizedBox(height: AkSpace.s1),
        // "more than came in" is money going out faster than it came, so it takes the out
        // colour; "less" takes the in colour, as Forecast.html draws it. The words carry the
        // meaning too.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${range == null ? '' : '${rangeInWords(range!, money)}. '}'
                    'That is about ',
              ),
              TextSpan(
                text: '${money(gap.abs())} ${gap >= 0 ? 'more' : 'less'}',
                style: t.bodySm.copyWith(
                  color: gap >= 0 ? c.moneyOut : c.moneyIn,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' than came in.'),
            ],
          ),
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s4),
        if (safe case SafeAmount(:final perDay))
          _FactRow(
            label: 'Safe to spend',
            value: '${money(perDay)} a day',
            valueColour: c.ink,
            detail: 'Income so far, less the forecast, shared over the days left.',
          )
        else if (safe case OverBy(:final amount))
          _FactRow(
            label: 'Over by',
            value: money(amount),
            valueColour: c.moneyOut,
            detail: 'The forecast is more than the income recorded this month.',
          ),
        if (pace != null)
          _FactRow(
            label: 'Pace against last month',
            value: money(pace.difference.abs()),
            valueColour: pace.difference >= 0 ? c.moneyOut : c.moneyIn,
            detail:
                '${pace.difference >= 0 ? 'More' : 'Less'} money out than the same days last month.',
          ),
        const SizedBox(height: AkSpace.s2),
        CumulativeLineChart(
          summary:
              'Money out so far ${money(forecast.spentSoFar)}, forecast '
              '${money(forecast.point)} by the end of the month.',
          actual: actual,
          forecast: path,
          forecastBand: range == null ? null : (range!.low.toDouble(), range!.high.toDouble()),
          colours: colours,
          hideFigures: hidden,
          income: moneyIn > 0 ? moneyIn.toDouble() : null,
          dayLabelOf: (i) => DateFormat('d').format(month.start.add(Duration(days: i))),
        ),
        const SizedBox(height: AkSpace.s2),
        Wrap(
          spacing: AkSpace.s3,
          runSpacing: AkSpace.s1,
          children: [
            Text('Solid is what you spent', style: t.caption.copyWith(color: c.inkMuted)),
            Text('Dotted is the forecast', style: t.caption.copyWith(color: c.inkMuted)),
          ],
        ),
        const SizedBox(height: AkSpace.s5),
        const AkEyebrow('How it adds up'),
        const SizedBox(height: AkSpace.s3),
        _StackedBar(
          money: money,
          spent: forecast.spentSoFar,
          everyday: forecast.everydayToCome,
          regular: forecast.regularDue,
        ),
        const SizedBox(height: AkSpace.s3),
        _SumRow(
          hidden: hidden,
          title: 'Spent so far',
          amount: forecast.spentSoFar,
          sign: '',
          dot: c.moneyOut,
          detail: 'Today so far ${money(forecast.everydayToday)}',
        ),
        _SumRow(
          hidden: hidden,
          title: forecast.daysLeft == 0
              ? 'Everyday, rest of today'
              : 'Everyday, rest of today and ${forecast.daysLeft} more days',
          detail: '${money(forecast.dailyRate)} a day',
          amount: forecast.everydayToCome,
          sign: '+ ',
          dot: c.brand,
        ),
        _SumRow(
          hidden: hidden,
          title: 'Regular bills due',
          amount: forecast.regularDue,
          sign: '+ ',
          dot: c.inkMuted,
          onTap: () => context.push(Routes.regular),
        ),
        if (forecast.regularBands.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s4),
          const AkEyebrow('Regular payments still due'),
          const SizedBox(height: AkSpace.s3),
          for (final due in forecast.regularBands)
            _SumRow(
              hidden: hidden,
              title: due.label,
              detail:
                  '${DateFormat('d MMM').format(due.due)}, '
                  '${money(due.low)} to ${money(due.high)}',
              amount: due.typical,
              sign: '',
              onTap: () => context.push(Routes.regular),
            ),
        ],
        if (leftOut.isNotEmpty) ...[
          const SizedBox(height: AkSpace.s4),
          const AkEyebrow('Left out as one-offs'),
          const SizedBox(height: AkSpace.s3),
          for (final row in leftOut)
            _SumRow(
              hidden: hidden,
              title: row.description.isEmpty ? 'One-off payment' : row.description,
              detail: DateFormat('d MMM').format(fromLocalDay(row.localDay)),
              amount: row.amount,
              sign: '',
              onTap: () => context.push(Routes.transaction(row.id)),
            ),
        ],
        _HowClose(dayOfMonth: today.day),
        const SizedBox(height: AkSpace.s4),
        Text(
          'Worked out on this phone from your last $historyDays days. One-off payments such as '
          'school fees are left out of the daily rate. It updates each time you add.'
          '${range == null ? '' : ' ${rangeEvidence(range!)}'}',
          style: t.caption.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

/// One line of a figure with a short explanation beneath it, such as "Safe to spend".
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    required this.valueColour,
    required this.detail,
  });

  final String label;
  final String value;
  final Color valueColour;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyMd.copyWith(color: c.ink)),
                const SizedBox(height: AkSpace.s1),
                Text(detail, style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: AkSpace.s3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: t.figure.copyWith(color: valueColour),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spent, everyday and regular money out as one bar. Its legend is the rows beneath it.
class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.spent,
    required this.everyday,
    required this.regular,
    required this.money,
  });

  final int spent;
  final int everyday;
  final int regular;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = [
      (spent, c.moneyOut),
      (everyday, c.brand),
      (regular, c.inkMuted),
    ].where((p) => p.$1 > 0).toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    return Semantics(
      image: true,
      container: true,
      excludeSemantics: true,
      label:
          'Spent ${money(spent)}, everyday ${money(everyday)}, '
          'regular bills ${money(regular)}.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.metrics.sm),
        child: SizedBox(
          height: AkSpace.s4,
          child: Row(
            children: [
              for (final part in parts)
                Expanded(
                  flex: part.$1,
                  child: ColoredBox(color: part.$2, child: const SizedBox.expand()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How close it has been", as Forecast.html draws it: for up to three earlier months, the
/// forecast made on this day of the month (dashed) beside what was really spent (solid).
/// A month with no saved forecast is left out; with none at all the section is not shown.
class _HowClose extends ConsumerWidget {
  const _HowClose({required this.dayOfMonth});

  /// Today's date in the calendar month. Every budget month starts on the same date, so the
  /// earlier forecasts were made on (or nearest to) this date too, whatever "Month starts on"
  /// says; the day within the budget month would name the wrong date.
  final int dayOfMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final history = ref.watch(forecastHistoryProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    String sh(int v) => hidden ? hiddenFigure : formatShort(v);
    String ug(int v) => hidden ? hiddenFigure : formatUgx(v);
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final largest = history.fold(0, (m, s) => math.max(m, math.max(s.point, s.actual)));
    final within = history.fold(0.0, (sum, s) => sum + ((s.actual - s.point) / s.point).abs());
    final percent = math.max(1, (within / history.length * 100).round());
    // "The 19th" in a settings row; here it sits inside a sentence.
    final day = ordinalDay(dayOfMonth).replaceFirst('The ', '');
    String month(SnapshotPoint s) => DateFormat('MMMM').format(fromLocalDay(s.periodStart));
    String short(SnapshotPoint s) => DateFormat('MMM').format(fromLocalDay(s.periodStart));
    String range(SnapshotPoint s) =>
        s.low == null || s.high == null ? '' : ', range ${sh(s.low!)} to ${sh(s.high!)}';
    final spoken = [
      for (final s in history)
        '${month(s)}: forecast ${ug(s.point)}${range(s)}, actual ${ug(s.actual)}',
    ].join('. ');
    final count = history.length == 1 ? 'last month' : 'the last ${history.length} months';
    double height(int v) => largest == 0 ? 0 : math.max(2, AkSize.barChartSm * v / largest);

    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AkSpace.s3,
            children: [
              Semantics(
                header: true,
                child: Text('How close it has been', style: t.title.copyWith(color: c.ink)),
              ),
              Text('within about $percent%', style: t.caption.copyWith(color: c.inkMuted)),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          Semantics(
            image: true,
            container: true,
            excludeSemantics: true,
            label:
                'For $count, the forecast made on the $day against what was actually '
                'spent. $spoken.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, s) in history.indexed) ...[
                  if (i > 0) const SizedBox(width: AkSpace.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: AkSize.barChartSm,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  key: ValueKey('forecast-${s.periodStart}'),
                                  height: height(s.point),
                                  child: AkDashedBox(
                                    color: c.switchOff,
                                    radius: context.metrics.sm,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AkSpace.s1),
                              Expanded(
                                child: Container(
                                  key: ValueKey('actual-${s.periodStart}'),
                                  height: height(s.actual),
                                  decoration: BoxDecoration(
                                    color: c.brand,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(context.metrics.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AkSpace.s1),
                        Text(
                          '${short(s)} ${sh(s.point)} / ${sh(s.actual)}',
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                        if (s.low != null && s.high != null)
                          Text(
                            'range ${sh(s.low!)} to ${sh(s.high!)}',
                            style: t.caption.copyWith(color: c.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ],
                // Fewer than three months keep the drawn width per month.
                for (var k = history.length; k < 3; k++) ...[
                  const SizedBox(width: AkSpace.s4),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Dashed is what was forecast on the $day. Solid is what you actually spent.',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow({
    required this.title,
    required this.amount,
    required this.sign,
    this.detail,
    this.dot,
    this.onTap,
    this.hidden = false,
  });

  final String title;
  final int amount;
  final String sign;
  final String? detail;

  /// The legend colour for this part of the stacked bar; null when the row is not in the bar.
  final Color? dot;

  /// Set for rows that open another screen (Coming up, one transaction).
  final VoidCallback? onTap;

  /// Amounts are hidden: the figure shows as dots.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Row(
        children: [
          if (dot != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              child: const SizedBox(width: AkSpace.s2, height: AkSpace.s2),
            ),
            const SizedBox(width: AkSpace.s2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyMd.copyWith(color: c.ink)),
                if (detail != null) ...[
                  const SizedBox(height: AkSpace.s1),
                  Text(detail!, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ],
            ),
          ),
          Text(
            hidden ? hiddenFigure : '$sign${formatAmount(amount)}',
            style: t.figure.copyWith(color: c.ink),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
