import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../app/close_screen.dart';
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
import '../../domain/calendar.dart' show heatStep;
import '../../domain/spending.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/category_donut.dart';
import '../home/home_providers.dart';
import '../insights/insights_text.dart';
import '../settings/settings_page.dart' show ordinalDay;

/// Categories: this month's money out, split by category, with the change on last month.
/// Fees and tax is listed last, built from the fee and tax fields.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    final rows = ref.watch(monthRowsProvider);
    final before = ref.watch(previousSameDaysRowsProvider);
    final cats = ref.watch(allCategoriesProvider);
    final chart = ref.watch(categoryChartProvider);
    final ready = rows.hasValue && before.hasValue && cats.hasValue;

    final current = moneyOutByCategory(rows.value ?? const <Transaction>[]);
    final previous = moneyOutByCategory(before.value ?? const <Transaction>[]);
    final names = {for (final cat in cats.value ?? const <Category>[]) cat.id: cat};
    final total = current.values.fold<int>(0, (a, b) => a + b);
    final against = DateFormat('MMMM').format(calc.previous(month).start);

    final ordered = current.keys.where((id) => id != DefaultIds.fees).toList()
      ..sort((a, b) => current[b]!.compareTo(current[a]!));
    final feesAmount = current[DefaultIds.fees];
    final top = ordered.take(2).toList();
    final reading = top.length < 2
        ? null
        : '${names[top[0]]?.name ?? 'Other'} and ${names[top[1]]?.name ?? 'Other'} are '
              '${formatPercent(shareOf(current[top[0]]! + current[top[1]]!, total))} '
              'of what you spent.';

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
              child: Text('Categories', style: t.displayLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s2),
            if (!ready && [rows, before, cats].any((a) => a.hasError))
              const AkEmptyNote(loadFailedText)
            else if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (total == 0)
              AkEmptyNote(
                'Nothing spent this month yet. Entries you add are grouped here.',
                actionLabel: 'Add a transaction',
                onAction: () => context.push(Routes.add),
              )
            else ...[
              if (chart == CategoryChart.pie)
                _PieHeader(
                  slices: donutSlices(
                    c,
                    [...ordered, if (feesAmount != null) DefaultIds.fees],
                    current,
                    names,
                  ),
                  total: total,
                  range: rangeText(month.start, today),
                  reading: reading ?? '${formatUgx(total)} out.',
                )
              else ...[
                Text(
                  '${rangeText(month.start, today)}, ${formatUgx(total)} out',
                  style: t.bodySm.copyWith(color: c.inkMuted),
                ),
                if (reading != null) ...[
                  const SizedBox(height: AkSpace.s1),
                  Text(reading, style: t.bodySm.copyWith(color: c.inkMuted)),
                ],
              ],
              const SizedBox(height: AkSpace.s4),
              for (final id in ordered)
                _CategoryRow(
                  category: names[id],
                  amount: current[id]!,
                  share: shareOf(current[id]!, total),
                  change: rowChange(current[id]!, previous[id] ?? 0, against),
                  bar: chart == CategoryChart.bars,
                  onTap: () => context.push(Routes.category(id)),
                ),
              if (feesAmount != null)
                _CategoryRow(
                  category: names[DefaultIds.fees],
                  amount: feesAmount,
                  share: shareOf(feesAmount, total),
                  change: rowChange(feesAmount, previous[DefaultIds.fees] ?? 0, against),
                  bar: chart == CategoryChart.bars,
                  onTap: () => context.push(Routes.fees),
                ),
              const SizedBox(height: AkSpace.s5),
              _DayByDay(
                month: month,
                today: today,
                rows: rows.value ?? const <Transaction>[],
                weekStartsOn: calc.weekStartsOn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Day by day", as Categories.html draws it: the month's days in weeks, each filled by how
/// much went out that day against the other days so far, the same steps as Calendar's month.
/// Days still to come are an empty outline.
class _DayByDay extends StatelessWidget {
  const _DayByDay({
    required this.month,
    required this.today,
    required this.rows,
    required this.weekStartsOn,
  });

  final Period month;
  final DateTime today;
  final List<Transaction> rows;

  /// [DateTime.monday] to [DateTime.sunday].
  final int weekStartsOn;

  static const _letters = {
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    // Money out per day as Home and Calendar count it: amounts, fees and tax.
    final grouped = <int, List<Transaction>>{};
    for (final r in rows) {
      (grouped[r.localDay] ??= []).add(r);
    }
    final byDay = {for (final e in grouped.entries) e.key: totalsOf(e.value).moneyOut};
    final days = [for (var i = 0; i < month.lengthInDays; i++) addDays(month.start, i)];
    final past = [
      for (final d in days)
        if (!d.isAfter(today)) byDay[toLocalDay(d)] ?? 0,
    ];
    final lead = (days.first.weekday - weekStartsOn + 7) % 7;
    final weekdays = [for (var i = 0; i < 7; i++) (weekStartsOn - 1 + i) % 7 + 1];

    // What it says aloud: the highest day, and from which day the grid is still empty.
    var highest = days.first;
    for (final d in days.where((d) => !d.isAfter(today))) {
      if ((byDay[toLocalDay(d)] ?? 0) > (byDay[toLocalDay(highest)] ?? 0)) highest = d;
    }
    String nth(DateTime d) => ordinalDay(d.day).replaceFirst('The ', 'the ');
    final name = DateFormat('MMMM').format(month.start);
    final spoken = [
      'Calendar of $name.',
      if ((byDay[toLocalDay(highest)] ?? 0) > 0) 'Spending was highest on ${nth(highest)}.',
      if (today.isBefore(month.lastDate)) 'Days after ${nth(today)} are still empty.',
    ].join(' ');

    Widget grid(List<Widget> cells) => GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AkSpace.s1,
      crossAxisSpacing: AkSpace.s1,
      childAspectRatio: 3,
      padding: EdgeInsets.zero,
      children: cells,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AkSpace.s3,
          children: [
            Semantics(
              header: true,
              child: Text('Day by day', style: t.title.copyWith(color: c.ink)),
            ),
            // The heat scale runs light to dark in light, and dark to light in dark.
            Text(
              Theme.of(context).brightness == Brightness.dark
                  ? 'brighter means more spent'
                  : 'darker means more spent',
              style: t.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s2),
        Semantics(
          image: true,
          container: true,
          excludeSemantics: true,
          label: spoken,
          child: grid([
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (final d in days)
              DecoratedBox(
                key: ValueKey('day-${d.day}'),
                decoration: d.isAfter(today)
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(context.metrics.xs),
                        border: Border.all(color: c.lineStrong),
                      )
                    : BoxDecoration(
                        color: heatColour(c, heatStep(byDay[toLocalDay(d)] ?? 0, past)),
                        borderRadius: BorderRadius.circular(context.metrics.xs),
                      ),
              ),
          ]),
        ),
        const SizedBox(height: AkSpace.s1),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final (i, w) in weekdays.indexed) ...[
                if (i > 0) const SizedBox(width: AkSpace.s1),
                Expanded(
                  child: Text(
                    _letters[w]!,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The donut's slices in list order (largest first, Fees and tax last). The donut takes six
/// slices at most, so from a seventh category on, the smallest are joined into one
/// `line-strong` slice read as "the rest".
List<DonutSlice> donutSlices(
  AkColorTokens c,
  List<String> ids,
  Map<String, int> amounts,
  Map<String, Category> names,
) {
  const most = 6;
  DonutSlice of(String id) => DonutSlice(
    name: names[id]?.name ?? 'Other',
    amount: amounts[id]!,
    colour: colourForToken(c, names[id]?.colourToken ?? 'cat-slate'),
  );
  if (ids.length <= most) return [for (final id in ids) of(id)];
  final byAmount = [...ids]..sort((a, b) => amounts[b]!.compareTo(amounts[a]!));
  final kept = byAmount.take(most - 1).toSet();
  final rest = byAmount.skip(most - 1).fold<int>(0, (sum, id) => sum + amounts[id]!);
  return [
    for (final id in ids)
      if (kept.contains(id)) of(id),
    DonutSlice(name: 'the rest', amount: rest, colour: c.lineStrong),
  ];
}

/// What the donut says to a screen reader, as Categories.html words it.
String donutLabel(List<DonutSlice> slices, int total) =>
    'Pie chart of money out by category: '
    '${slices.map((s) => '${s.name.toLowerCase()} ${formatPercent(shareOf(s.amount, total))}').join(', ')}';

/// The drawn top of Categories with Pie chosen: the donut with the total in its centre, and
/// beside it the dates and the one-sentence reading.
class _PieHeader extends StatelessWidget {
  const _PieHeader({
    required this.slices,
    required this.total,
    required this.range,
    required this.reading,
  });

  final List<DonutSlice> slices;
  final int total;
  final String range;
  final String reading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Row(
      children: [
        CategoryDonut(
          slices: slices,
          centre: formatShort(total),
          centreCaption: 'money out',
          semanticLabel: donutLabel(slices, total),
        ),
        const SizedBox(width: AkSpace.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AkEyebrowLabel(range),
              const SizedBox(height: AkSpace.s2),
              Text(reading, style: t.headlineSm.copyWith(color: c.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The change on a category row, or null when there is nothing to compare with: said once
/// per row it would repeat down the whole list, so the row then shows its share alone.
String? rowChange(int current, int previous, String against) =>
    percentChange(current: current, previous: previous) == null
    ? null
    : comparison(current, previous, against);

/// "Up 4% on October", or a sentence that there is nothing to compare with. [previous] is the
/// same days of [against], not all of it, so the empty sentence says "by this day": October
/// may well have fees after the 23rd.
String comparison(int current, int previous, String against) {
  final percent = percentChange(current: current, previous: previous);
  if (percent == null) return 'Nothing by this day in $against to compare with.';
  if (percent == 0) return 'Level with $against';
  final word = percent > 0 ? 'Up' : 'Down';
  return '$word ${formatPercent(percent.abs().toDouble())} on $against';
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.share,
    required this.change,
    required this.bar,
    required this.onTap,
  });

  final Category? category;
  final int amount;
  final double share;
  final String? change;

  /// A share bar under the name, when "Category chart" is Bars.
  final bool bar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final name = category?.name ?? 'Other';
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = categoryIconColour(c, category?.colourToken ?? 'cat-slate');
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          '$name, ${formatUgx(amount)}, ${formatPercent(share)} of money out.${change == null ? '' : ' $change'}',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(color: c.ink),
                          ),
                        ),
                        Text(formatAmount(amount), style: t.figure.copyWith(color: c.ink)),
                      ],
                    ),
                    if (bar) ...[
                      const SizedBox(height: AkSpace.s1),
                      ShareBar(fraction: share / 100, colour: colour),
                    ],
                    const SizedBox(height: AkSpace.s1),
                    Text(
                      change == null ? formatPercent(share) : '${formatPercent(share)} · $change',
                      style: t.caption.copyWith(color: c.inkMuted),
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

/// A share bar: a fill over a `line` track, 6 to 10px with `radius-sm`.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.fraction, required this.colour});

  final double fraction;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AkRadiusTokens.sm),
      child: Stack(
        children: [
          Container(height: AkSize.bar, color: c.line),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0, 1).toDouble(),
            child: Container(height: AkSize.bar, color: colour),
          ),
        ],
      ),
    );
  }
}
