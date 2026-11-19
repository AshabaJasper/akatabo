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
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../home/home_providers.dart';
import 'transaction_row.dart';
import 'transactions_providers.dart';

enum _Kind { all, moneyOut, moneyIn }

/// All transactions: search, a kind filter, the month's money out by day, and every entry
/// grouped by day with the day's net total.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  _Kind _kind = _Kind.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Transaction t) {
    final kindOk = switch (_kind) {
      _Kind.all => true,
      _Kind.moneyOut => t.direction == Direction.moneyOut,
      _Kind.moneyIn => t.direction == Direction.moneyIn,
    };
    if (!kindOk) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp('[^0-9]'), '');
    return t.description.toLowerCase().contains(q) ||
        (t.note ?? '').toLowerCase().contains(q) ||
        (digits.isNotEmpty && t.amount.toString().contains(digits));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final all = ref.watch(allTransactionsProvider).value ?? const <Transaction>[];
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };
    final monthRows = ref.watch(monthRowsProvider).value ?? const <Transaction>[];
    final shown = all.where(_matches).toList();

    // Rows arrive newest first, so each day's rows are already in order.
    final days = <int, List<Transaction>>{};
    for (final tx in shown) {
      days.putIfAbsent(tx.localDay, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Home', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s2),
            Text('Transactions', style: t.displayLg.copyWith(color: c.ink)),
            const SizedBox(height: AkSpace.s4),
            _SearchField(controller: _search, onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: AkSpace.s3),
            AkSegmented<_Kind>(
              semanticLabel: 'Filter',
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
              segments: const [
                AkSegment(_Kind.all, 'All'),
                AkSegment(_Kind.moneyOut, 'Money out'),
                AkSegment(_Kind.moneyIn, 'Money in'),
              ],
            ),
            const SizedBox(height: AkSpace.s5),
            if (monthRows.isNotEmpty) ...[
              _DailyBars(rows: monthRows, now: now),
              const SizedBox(height: AkSpace.s5),
            ],
            if (all.isEmpty)
              const _Notice('Nothing here yet. Entries you add appear here, newest first.')
            else if (shown.isEmpty)
              const _Notice('No entries match. Try another word or amount.')
            else
              for (final entry in days.entries) ...[
                _DayHeader(day: entry.key, rows: entry.value, now: now),
                for (final tx in entry.value)
                  TransactionRow(
                    transaction: tx,
                    now: now,
                    category: categories[tx.categoryId],
                    accountName: accounts[tx.accountId] ?? '',
                    toAccountName: tx.toAccountId == null ? null : accounts[tx.toAccountId],
                    onTap: () => context.push(Routes.transaction(tx.id)),
                  ),
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
