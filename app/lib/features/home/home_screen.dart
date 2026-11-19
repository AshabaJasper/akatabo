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
import '../../data/seed/default_data.dart';
import '../../domain/spending.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
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

    final monthName = DateFormat('MMMM').format(now);
    final prevName = DateFormat('MMMM').format(ref.watch(previousSameDaysProvider).start);
    final rows = ref.watch(monthRowsProvider).value ?? const <Transaction>[];
    final previousRows = ref.watch(previousSameDaysRowsProvider).value ?? const <Transaction>[];
    final categories = {
      for (final c in ref.watch(allCategoriesProvider).value ?? const <Category>[]) c.id: c,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };

    final totals = totalsOf(rows);
    final previousOut = totalsOf(previousRows).moneyOut;
    final change = percentChange(current: totals.moneyOut, previous: previousOut);
    final parts = moneyOutByCategory(rows);
    final feesAndTax = parts[DefaultIds.fees] ?? 0;

    return Scaffold(
      backgroundColor: context.colors.ground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            monthName: monthName,
            caption: 'Money out, 1 to ${now.day} $monthName',
            figure: formatUgx(totals.moneyOut),
            comparison: change == null || previousOut == 0
                ? null
                : change >= 0
                ? '$change% above this point in $prevName'
                : '${-change}% below this point in $prevName',
            tiles: [
              _StatTile(label: 'Money in', value: formatShort(totals.moneyIn)),
              _StatTile(label: 'Fees and tax', value: formatAmount(feesAndTax)),
            ],
          ),
          const SizedBox(height: AkSpace.s5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
            child: _WhereItWent(parts: parts, categories: categories, total: totals.moneyOut),
          ),
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
  final String figure;
  final String? comparison;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    // The header sits under the status bar and is dark green in both themes, so the clock
    // and icons above it are light whatever the theme says.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: c.brand.withValues(alpha: 0)),
      child: Container(
        color: c.brand,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s3, AkSpace.s6, AkSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Akatabo', style: t.displaySm.copyWith(color: c.onBrand)),
                    const Spacer(),
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
                        child: InkWell(
                          onTap: () => context.push(Routes.calendar),
                          borderRadius: BorderRadius.circular(context.metrics.pill),
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
                  ],
                ),
                const SizedBox(height: AkSpace.s3h),
                Text(caption, style: t.bodySm.copyWith(color: c.onBrandMuted)),
                const SizedBox(height: AkSpace.s1),
                Text(figure, style: t.figureXl.copyWith(color: c.onBrand)),
                if (comparison != null) ...[
                  const SizedBox(height: AkSpace.s1),
                  Text(comparison!, style: t.bodySm.copyWith(color: c.accent)),
                ],
                const SizedBox(height: AkSpace.s4),
                Row(
                  children: [
                    for (final (i, tile) in tiles.indexed) ...[
                      if (i > 0) const SizedBox(width: AkSpace.s2),
                      Expanded(child: tile),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(AkSpace.s2h),
      decoration: BoxDecoration(
        color: c.brandRaised,
        borderRadius: BorderRadius.circular(context.metrics.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.caption.copyWith(color: c.onBrandMuted)),
          const SizedBox(height: AkSpace.s0h),
          Text(value, style: t.bodyStrong.copyWith(color: c.onBrand)),
        ],
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
        const AkSectionTitle('Where it went'),
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

class _SplitRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final name = category?.name ?? 'Other';
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = ThemeData.estimateBrightnessForColor(colour) == Brightness.light
        ? c.ink
        : c.onBrand;
    final shareText = formatPercent(share);

    return Semantics(
      label: '$name, ${formatAmount(amount)}, $shareText of money out',
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
                      Text(formatAmount(amount), style: t.figure.copyWith(color: c.ink)),
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
            figure: formatUgx(0),
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
                AkCard(
                  child: Column(
                    children: [
                      AkIcon(AkIcons.chart, color: c.inkMuted),
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
              ],
            ),
          ),
        ],
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
