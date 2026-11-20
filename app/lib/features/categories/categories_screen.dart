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
import '../../domain/spending.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../../widgets/charts/category_donut.dart';
import '../home/home_providers.dart';
import '../insights/insights_text.dart';

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
            if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (total == 0)
              const AkEmptyNote('Nothing spent this month yet. Entries you add are grouped here.')
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
                  change: comparison(current[id]!, previous[id] ?? 0, against),
                  bar: chart == CategoryChart.bars,
                  onTap: () => context.push(Routes.category(id)),
                ),
              if (feesAmount != null)
                _CategoryRow(
                  category: names[DefaultIds.fees],
                  amount: feesAmount,
                  share: shareOf(feesAmount, total),
                  change: comparison(feesAmount, previous[DefaultIds.fees] ?? 0, against),
                  bar: chart == CategoryChart.bars,
                  onTap: () => context.push(Routes.fees),
                ),
            ],
          ],
        ),
      ),
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

/// "Up 4% on October", or a sentence that there is nothing to compare with.
String comparison(int current, int previous, String against) {
  final percent = percentChange(current: current, previous: previous);
  if (percent == null) return 'Nothing in $against to compare with.';
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
  final String change;

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
      label: '$name, ${formatUgx(amount)}, ${formatPercent(share)} of money out. $change',
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
                      '${formatPercent(share)} · $change',
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
