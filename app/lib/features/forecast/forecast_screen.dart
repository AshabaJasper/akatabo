import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/forecast.dart';
import '../../domain/insights.dart';
import '../../domain/spending.dart';
import '../../smart/forecast/forecast_range.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/cumulative_line.dart';
import '../home/home_providers.dart';
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
