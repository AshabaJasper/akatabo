import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/calendar.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../home/home_providers.dart';
import '../insights/insights_text.dart';
import 'categories_screen.dart';

/// One category, the same page for every category: School fees, Transport, Bills, Other and
/// the rest. Its total is the amount of its entries; fees and tax are in their own category.
class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final today = dateOnly(now);
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    final rowsAsync = ref.watch(monthRowsProvider);
    final beforeAsync = ref.watch(previousSameDaysRowsProvider);
    final catsAsync = ref.watch(allCategoriesProvider);
    final ready = rowsAsync.hasValue && beforeAsync.hasValue && catsAsync.hasValue;

    final category = catsAsync.value?.where((cat) => cat.id == categoryId).firstOrNull;
    final mine = [
      for (final t in rowsAsync.value ?? const <Transaction>[])
        if (t.direction == Direction.moneyOut && t.categoryId == categoryId) t,
    ];
    final minePrevious = [
      for (final t in beforeAsync.value ?? const <Transaction>[])
        if (t.direction == Direction.moneyOut && t.categoryId == categoryId) t,
    ];
    final total = mine.fold<int>(0, (a, tx) => a + tx.amount);
    final previousTotal = minePrevious.fold<int>(0, (a, tx) => a + tx.amount);
    final against = DateFormat('MMMM').format(calc.previous(month).start);
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = ThemeData.estimateBrightnessForColor(colour) == Brightness.light
        ? c.ink
        : c.onBrand;

    // Money out by day, for this category only, so the weeks add back to its total.
    final byDay = <int, int>{};
    for (final tx in mine) {
      byDay.update(tx.localDay, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final weeks = weekMarks(month, byDay, now, calc);
    final biggestWeek = weeks.fold<int>(0, (m, w) => w.moneyOut > m ? w.moneyOut : m);

    final payees = _payees(mine);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Categories', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s3),
            Row(
              children: [
                AkIconTile(
                  icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
                  background: colour,
                  foreground: ink,
                  size: AkSize.tileMd,
                ),
                const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      category?.name ?? 'Other',
                      style: t.displayLg.copyWith(color: c.ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            if (!ready)
              const SizedBox(height: AkSize.chart)
            else if (mine.isEmpty)
              AkEmptyNote(
                'Nothing spent on ${category?.name.toLowerCase() ?? 'this'} this month yet.',
              )
            else ...[
              Text(
                '${rangeText(month.start, today)}, ${mine.length} '
                '${mine.length == 1 ? 'transaction' : 'transactions'}',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s1),
              Text(formatUgx(total), style: t.figureXl.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s1),
              Text(
                comparison(total, previousTotal, against),
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: AkSpace.s5),
              const AkEyebrow('Week by week'),
              const SizedBox(height: AkSpace.s2),
              SizedBox(
                height: AkSize.chart,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final w in weeks)
                      Expanded(
                        child: Semantics(
                          label:
                              'Week from ${DateFormat('d MMMM').format(w.start)}, '
                              '${w.state == MarkState.future ? 'not yet' : formatUgx(w.moneyOut)}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s1),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: biggestWeek == 0
                                      ? 0
                                      : AkSize.chart * 0.8 * (w.moneyOut / biggestWeek),
                                  decoration: BoxDecoration(
                                    color: colour,
                                    borderRadius: BorderRadius.circular(AkRadiusTokens.xs),
                                  ),
                                ),
                                const SizedBox(height: AkSpace.s1h),
                                Text(
                                  DateFormat('d').format(w.start),
                                  style: t.caption.copyWith(color: c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AkSpace.s5),
              const AkEyebrow('What it went on'),
              for (final p in payees)
                AkListRow(
                  title: p.name,
                  subtitle: '${p.count} ${p.count == 1 ? 'time' : 'times'}',
                  trailing: Text(formatAmount(p.total), style: t.figure.copyWith(color: c.ink)),
                  divider: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Payee {
  _Payee(this.name);
  final String name;
  int count = 0;
  int total = 0;
}

/// The places this category was spent at, biggest first, at most four.
List<_Payee> _payees(List<Transaction> rows) {
  final byKey = <String, _Payee>{};
  for (final tx in rows) {
    final key = tx.payeeKey.isEmpty ? tx.description : tx.payeeKey;
    final p = byKey.putIfAbsent(
      key,
      () => _Payee(tx.description.isEmpty ? 'No name' : tx.description),
    );
    p.count++;
    p.total += tx.amount;
  }
  final list = byKey.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  return list.take(4).toList();
}
