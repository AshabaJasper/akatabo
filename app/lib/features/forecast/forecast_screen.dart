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
  });

  final Forecast forecast;

  /// The range around the forecast; null when "Forecast the month" is off.
  final ForecastRange? range;
  final Period month;
  final DateTime today;
  final List<Transaction> monthRows;
  final int moneyIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatUgx(forecast.point), style: t.figureXl.copyWith(color: c.ink)),
        const SizedBox(height: AkSpace.s1),
        Text(
          '${range == null ? '' : '${rangeInWords(range!, formatUgx)}. '}'
          'That is about ${formatUgx(gap.abs())} ${gap >= 0 ? 'more' : 'less'} than came in.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s4),
        CumulativeLineChart(
          summary:
              'Money out so far ${formatUgx(forecast.spentSoFar)}, forecast '
              '${formatUgx(forecast.point)} by the end of the month.',
          actual: actual,
          forecast: path,
          forecastBand: range == null ? null : (range!.low.toDouble(), range!.high.toDouble()),
          colours: colours,
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
        _SumRow(title: 'Spent so far', amount: forecast.spentSoFar, sign: ''),
        _SumRow(
          title: forecast.daysLeft == 0
              ? 'Everyday, rest of today'
              : 'Everyday, rest of today and ${forecast.daysLeft} more days',
          detail: '${formatUgx(forecast.dailyRate)} a day',
          amount: forecast.everydayToCome,
          sign: '+ ',
        ),
        _SumRow(title: 'Regular bills due', amount: forecast.regularDue, sign: '+ '),
        _HowClose(dayInMonth: daysBetween(month.start, today) + 1),
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

/// "How close it has been", as Forecast.html draws it: for up to three earlier months, the
/// forecast made on this day of the month (dashed) beside what was really spent (solid).
/// A month with no saved forecast is left out; with none at all the section is not shown.
class _HowClose extends ConsumerWidget {
  const _HowClose({required this.dayInMonth});

  final int dayInMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final history = ref.watch(forecastHistoryProvider);
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final largest = history.fold(0, (m, s) => math.max(m, math.max(s.point, s.actual)));
    final within = history.fold(0.0, (sum, s) => sum + ((s.actual - s.point) / s.point).abs());
    final percent = math.max(1, (within / history.length * 100).round());
    // "The 19th" in a settings row; here it sits inside a sentence.
    final day = ordinalDay(dayInMonth).replaceFirst('The ', '');
    String month(SnapshotPoint s) => DateFormat('MMMM').format(fromLocalDay(s.periodStart));
    String short(SnapshotPoint s) => DateFormat('MMM').format(fromLocalDay(s.periodStart));
    final spoken = [
      for (final s in history)
        '${month(s)}: forecast ${formatUgx(s.point)}, actual ${formatUgx(s.actual)}',
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
                          '${short(s)} ${formatShort(s.point)} / ${formatShort(s.actual)}',
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
  const _SumRow({required this.title, required this.amount, required this.sign, this.detail});

  final String title;
  final int amount;
  final String sign;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s3),
      child: Row(
        children: [
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
          Text('$sign${formatAmount(amount)}', style: t.figure.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
