import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/spending.dart';
import '../../domain/transaction_filter.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../filters/date_choice_providers.dart';
import '../filters/transaction_filter_providers.dart';
import '../home/home_providers.dart';
import 'transaction_row.dart';
import 'transactions_providers.dart';

/// All transactions: search, a kind filter, the month's money out by day, and every entry
/// grouped by day with the day's net total.
///
/// With [day] (yyyymmdd, from Calendar's "See that day") it shows only that day.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.day, this.fromCalendar = false});

  final int? day;

  /// Opened from Calendar's "List": back and the Calendar button return to it.
  final bool fromCalendar;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // The search words and direction are held in the filter, so they are still here when the
    // person comes back from Filters.
    _search = TextEditingController(text: ref.read(transactionFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The search words live in the filter, so another screen (the day view, or a list pushed
    // from it) can change them. Keep the box showing what is really applied.
    ref.listen(transactionFilterProvider.select((f) => f.query), (_, q) {
      if (_search.text != q) _search.text = q;
    });
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final allAsync = ref.watch(allTransactionsProvider);
    final all = allAsync.value ?? const <Transaction>[];
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };
    final monthRows = ref.watch(monthRowsProvider).value ?? const <Transaction>[];
    final filter = ref.watch(transactionFilterProvider);
    final period = ref.watch(chosenPeriodProvider);
    final oneDay = widget.day != null;
    // The day view has the search box and direction, not the Filters choices or dates, so it
    // uses only those and stays newest first.
    final scope = oneDay ? filter.listControlsOnly : filter;
    final order = oneDay ? FilterOrder.newest : filter.order;
    final shown = orderedRows(
      all
          .where((tx) => !oneDay || tx.localDay == widget.day)
          .where((tx) => matchesFilter(tx, scope, oneDay ? null : period))
          .toList(),
      order,
    );
    // Filters on: a Filters choice or a date range. Search and direction have their own controls.
    final filtersOn = filter.narrows || period != null;
    final listNarrowed = filter.query.trim().isNotEmpty || filter.kind != TransactionKind.all;

    // Rows arrive in the chosen order, so each day's rows are in order too.
    final days = <int, List<Transaction>>{};
    for (final tx in shown) {
      days.putIfAbsent(tx.localDay, () => []).add(tx);
    }

    Widget rowFor(Transaction tx) => TransactionRow(
      transaction: tx,
      now: now,
      category: categories[tx.categoryId],
      accountName: accounts[tx.accountId] ?? '',
      toAccountName: tx.toAccountId == null ? null : accounts[tx.toAccountId],
      onTap: () => context.push(Routes.transaction(tx.id)),
    );

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            Row(
              children: [
                AkBackLink(
                  oneDay || widget.fromCalendar ? 'Calendar' : 'Home',
                  onTap: () => closeScreen(context),
                ),
                const Spacer(),
                if (!oneDay) ...[
                  AkPillButton(
                    label: filtersOn ? 'Filters on' : 'Filters',
                    icon: AkIcons.filter,
                    onTap: () => context.push(Routes.filters),
                  ),
                  const SizedBox(width: AkSpace.s2),
                ],
                if (!oneDay)
                  AkPillButton(
                    label: 'Calendar',
                    icon: AkIcons.calendar,
                    // From Calendar, go back to it rather than stacking a second one.
                    onTap: widget.fromCalendar
                        ? () => closeScreen(context)
                        : () => context.push(Routes.calendarFromList),
                  ),
              ],
            ),
            const SizedBox(height: AkSpace.s2),
            Text(
              oneDay ? DateFormat('EEEE d MMMM').format(fromLocalDay(widget.day!)) : 'Transactions',
              style: t.displayLg.copyWith(color: c.ink),
            ),
            const SizedBox(height: AkSpace.s4),
            _SearchField(
              controller: _search,
              onChanged: (v) => ref.read(transactionFilterProvider.notifier).setQuery(v),
            ),
            const SizedBox(height: AkSpace.s3),
            AkSegmented<TransactionKind>(
              semanticLabel: 'Filter',
              selected: filter.kind,
              onChanged: (k) => ref.read(transactionFilterProvider.notifier).setKind(k),
              segments: const [
                AkSegment(TransactionKind.all, 'All'),
                AkSegment(TransactionKind.moneyOut, 'Money out'),
                AkSegment(TransactionKind.moneyIn, 'Money in'),
              ],
            ),
            const SizedBox(height: AkSpace.s5),
            if (!oneDay && monthRows.isNotEmpty) ...[
              _DailyBars(rows: monthRows, now: now),
              const SizedBox(height: AkSpace.s5),
            ],
            // Nothing is said until the entries have loaded: "nothing here" must be true.
            if (!allAsync.hasValue)
              const SizedBox.shrink()
            else if (oneDay && all.every((tx) => tx.localDay != widget.day))
              const _Notice('Nothing added on this day.')
            else if (all.isEmpty)
              const _Notice('Nothing here yet. Entries you add appear here, newest first.')
            else if (shown.isEmpty)
              _Notice(
                // Say what actually emptied the list: the Filters choices, or the search word.
                filtersOn && !listNarrowed
                    ? 'Nothing matches these filters. Clear all in Filters.'
                    : 'No entries match. Try another word or amount.',
              )
            else if (order == FilterOrder.largest)
              // Largest is one list, not days: the biggest first, whatever the day.
              for (final tx in shown) ...[rowFor(tx), const SizedBox(height: AkSpace.s2)]
            else
              for (final entry in days.entries) ...[
                _DayHeader(day: entry.key, rows: entry.value, now: now),
                for (final tx in entry.value) rowFor(tx),
                const SizedBox(height: AkSpace.s4),
              ],
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      label: 'Search transactions',
      textField: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AkSize.input),
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(context.metrics.lg),
          border: Border.all(color: c.lineStrong),
        ),
        child: Row(
          children: [
            AkIcon(AkIcons.search, color: c.inkMuted, size: AkSize.iconSm),
            const SizedBox(width: AkSpace.s2),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: t.bodyMd.copyWith(color: c.ink),
                cursorColor: c.brand,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search a name, note or amount',
                  hintStyle: t.bodyMd.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heading for one day: "Today, 19 Nov", "Yesterday, 18 Nov", "Tuesday, 17 Nov", with the
/// day's net total on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.rows, required this.now});

  final int day;
  final List<Transaction> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final when = fromLocalDay(day);
    final gap = daysBetween(dateOnly(when), dateOnly(now));
    final short = DateFormat('d MMM').format(when);
    final label = switch (gap) {
      0 => 'Today, $short',
      1 => 'Yesterday, $short',
      _ => '${DateFormat('EEEE').format(when)}, $short',
    };
    final totals = totalsOf(rows);
    final net = totals.net;
    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.caption.copyWith(color: c.inkMuted)),
          ),
          Text(
            formatSigned(net.abs(), moneyIn: net >= 0),
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Money out for each day of the month so far, as bars, with the biggest day named in words.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.rows, required this.now});

  final List<Transaction> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final perDay = <int, int>{};
    for (final tx in rows) {
      perDay.update(tx.localDay, (v) => v + moneyOutOf(tx), ifAbsent: () => moneyOutOf(tx));
    }
    final days = [for (var d = 1; d <= now.day; d++) d];
    final values = [
      for (final d in days) perDay[toLocalDay(DateTime(now.year, now.month, d))] ?? 0,
    ];
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    final biggest = values.indexOf(max);
    final summary = max == 0
        ? 'No money out yet this month.'
        : 'The biggest day was ${biggest + 1} ${DateFormat('MMMM').format(now)}, ${formatUgx(max)}.';

    return Semantics(
      label: 'Money out each day this month. $summary',
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Money out each day, ${DateFormat('MMMM').format(now)}',
            style: t.bodyStrong.copyWith(color: c.ink),
          ),
          const SizedBox(height: AkSpace.s1),
          Text(summary, style: t.bodySm.copyWith(color: c.inkMuted)),
          const SizedBox(height: AkSpace.s3),
          SizedBox(
            height: AkSize.catCell,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s0h / 2),
                      child: FractionallySizedBox(
                        heightFactor: max == 0 ? 0 : v / max,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.brand,
                            borderRadius: BorderRadius.circular(AkSize.bar / 2),
                          ),
                        ),
                      ),
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

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return AkCard(
      child: Text(text, style: t.bodySm.copyWith(color: c.inkMuted)),
    );
  }
}
