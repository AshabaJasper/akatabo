import 'package:clock/clock.dart';
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
import '../../data/providers.dart';
import '../../domain/calendar.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_dashed_box.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import '../home/home_providers.dart';
import '../transactions/transaction_row.dart';
import 'calendar_providers.dart';

const _kinds = [
  PeriodKind.day,
  PeriodKind.week,
  PeriodKind.month,
  PeriodKind.quarter,
  PeriodKind.year,
];

String _kindLabel(PeriodKind k) => switch (k) {
  PeriodKind.day => 'Day',
  PeriodKind.week => 'Week',
  PeriodKind.month => 'Month',
  // The same word as Insights uses for the same period.
  PeriodKind.quarter => '3 months',
  PeriodKind.year => 'Year',
  PeriodKind.custom => 'Dates',
};

/// "Thursday 19 November".
String _dayName(DateTime d) => DateFormat('EEEE d MMMM').format(d);

/// "16 to 22 November", or "30 November to 6 December" across a month end.
String _range(DateTime first, DateTime last) => first.month == last.month
    ? '${first.day} to ${DateFormat('d MMMM').format(last)}'
    : '${DateFormat('d MMMM').format(first)} to ${DateFormat('d MMMM').format(last)}';

/// The heading for a period. A month is named after the month it starts in.
String periodTitle(Period p) => switch (p.kind) {
  PeriodKind.day => _dayName(p.start),
  PeriodKind.week || PeriodKind.custom => _range(p.start, p.lastDate),
  PeriodKind.month => DateFormat('MMMM yyyy').format(p.start),
  PeriodKind.quarter =>
    '${DateFormat('MMMM').format(p.start)} to '
        '${DateFormat('MMMM yyyy').format(DateTime(p.start.year, p.start.month + 2))}',
  PeriodKind.year => '${p.start.year}',
};

/// Calendar: one screen, five periods. Month is a heat grid of days; the others are bars.
/// The current day, week or month is the darkest mark; what has not happened yet is an
/// outline, never a zero.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.fromList = false});

  /// Opened from All transactions: the back link and "List" return there.
  final bool fromList;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  PeriodKind _kind = PeriodKind.month;

  /// A day inside the period on screen; null means today.
  DateTime? _anchor;

  /// The day whose total shows in the card; null means today when it is on screen.
  DateTime? _selected;

  void _openList() {
    if (widget.fromList) {
      closeScreen(context);
    } else {
      context.push(Routes.transactionsFromCalendar);
    }
  }

  void _step(Period period, PeriodCalculator calc, {required bool later}) {
    final next = later ? calc.next(period) : calc.previous(period);
    setState(() {
      _anchor = next.start;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final now = ref.watch(appNowProvider);
    final today = dateOnly(now);
    final calc = ref.watch(periodCalculatorProvider);
    final period = calc.of(_kind, _anchor ?? today);
    // A new period starts with nothing loaded. Until its rows arrive the screen shows no
    // figures at all, so nobody sees (or hears) a "UGX 0" that is not true.
    final rowsAsync = ref.watch(calendarRowsProvider(period));
    final loaded = rowsAsync.hasValue;
    final rows = rowsAsync.value ?? const <Transaction>[];
    final byDay = moneyOutByDay(rows);
    final total = byDay.values.fold<int>(0, (a, b) => a + b);
    final isCurrent = period.contains(today);
    final canGoLater = !calc.next(period).start.isAfter(today);
    final selected = _selected != null && period.contains(_selected!)
        ? _selected!
        : (isCurrent ? today : null);

    final body = !loaded
        ? (rowsAsync.hasError
              ? const _Empty('These entries could not be read. Close Calendar and try again.')
              : const SizedBox(height: AkSize.chart))
        : switch (_kind) {
            PeriodKind.month => _MonthView(
              period: period,
              byDay: byDay,
              now: now,
              weekStartsOn: calc.weekStartsOn,
              selected: selected,
              onSelect: (d) => setState(() => _selected = d),
            ),
            PeriodKind.week => _BarsView(
              marks: dayMarks(period, byDay, now),
              label: (m) => DateFormat('E d').format(m.start),
              markName: (m) => _dayName(m.start),
              emptyText: 'Nothing spent in this week.',
              selected: selected,
              onSelect: (d) => setState(() => _selected = d),
            ),
            PeriodKind.day => _DayView(day: period.start, rows: rows, now: now),
            PeriodKind.quarter => _BarsView(
              marks: weekMarks(period, byDay, now, calc),
              label: (m) =>
                  _firstOfMonthIn(m) == null ? '' : DateFormat('MMM').format(_firstOfMonthIn(m)!),
              markName: (m) => 'Week of ${_range(m.start, addDays(m.end, -1))}',
              emptyText: 'Nothing spent in this quarter.',
              footer: (marks) =>
                  _busiest(marks, (m) => _range(m.start, addDays(m.end, -1)), 'week'),
            ),
            PeriodKind.year => _BarsView(
              marks: monthMarks(period, byDay, now, calc),
              label: (m) => DateFormat('MMM').format(m.start),
              markName: (m) => DateFormat('MMMM yyyy').format(m.start),
              emptyText: 'Nothing spent in this year.',
              footer: (marks) => _YearFacts(summary: summariseYear(marks)),
            ),
            PeriodKind.custom => const SizedBox.shrink(),
          };

    final dayCard =
        loaded && (_kind == PeriodKind.month || _kind == PeriodKind.week) && selected != null
        ? _DayCard(
            day: selected,
            amount: byDay[toLocalDay(selected)] ?? 0,
            onOpen: () => context.push(Routes.transactionsOn(toLocalDay(selected))),
          )
        : null;

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      AkBackLink(
                        widget.fromList ? 'Transactions' : 'Home',
                        onTap: () => closeScreen(context),
                      ),
                      const Spacer(),
                      AkPillButton(label: 'List', icon: AkIcons.list, onTap: _openList),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s3),
                  AkSegmented<PeriodKind>(
                    semanticLabel: 'Period',
                    selected: _kind,
                    onChanged: (k) => setState(() {
                      _anchor = selected ?? _anchor;
                      _kind = k;
                    }),
                    segments: [for (final k in _kinds) AkSegment(k, _kindLabel(k))],
                  ),
                  const SizedBox(height: AkSpace.s3),
                  Row(
                    children: [
                      _StepButton(
                        icon: AkIcons.back,
                        label: 'Earlier',
                        onTap: () => _step(period, calc, later: false),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              periodTitle(period),
                              textAlign: TextAlign.center,
                              style: t.displaySm.copyWith(color: c.ink),
                            ),
                            Text(
                              loaded ? '${formatUgx(total)} out${isCurrent ? ' so far' : ''}' : '',
                              textAlign: TextAlign.center,
                              style: t.bodySm.copyWith(color: c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      _StepButton(
                        icon: AkIcons.chevron,
                        label: 'Later',
                        onTap: canGoLater ? () => _step(period, calc, later: true) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AkSpace.s3),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    body,
                    if (dayCard != null) ...[
                      const SizedBox(height: AkSpace.s3),
                      const Spacer(),
                      dayCard,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 1st of a month when it falls inside [m], for the month labels under quarter weeks.
DateTime? _firstOfMonthIn(CalendarMark m) {
  for (var d = m.start; d.isBefore(m.end); d = addDays(d, 1)) {
    if (d.day == 1) return d;
  }
  return null;
}

Widget _busiest(List<CalendarMark> marks, String Function(CalendarMark) name, String unit) {
  final happened = marks.where((m) => m.state != MarkState.future && m.moneyOut > 0).toList();
  if (happened.isEmpty) return const SizedBox.shrink();
  final top = happened.reduce((a, b) => b.moneyOut > a.moneyOut ? b : a);
  return _Caption('The busiest $unit was ${name(top)}, ${formatUgx(top.moneyOut)}.');
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AkSpace.s3),
    child: Text(text, style: context.type.bodySm.copyWith(color: context.colors.inkMuted)),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});

  final AkIcons icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AkSize.target / 2,
        child: SizedBox.square(
          dimension: AkSize.target,
          child: Center(child: AkIcon(icon, color: onTap == null ? c.lineStrong : c.ink)),
        ),
      ),
    );
  }
}

Color _heatColour(AkColorTokens c, int step) => switch (step) {
  0 => c.heat0,
  1 => c.heat1,
  2 => c.heat2,
  _ => c.heat4,
};

/// Month: a heat grid of days with a legend.
class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.period,
    required this.byDay,
    required this.now,
    required this.weekStartsOn,
    required this.selected,
    required this.onSelect,
  });

  final Period period;
  final Map<int, int> byDay;
  final DateTime now;
  final int weekStartsOn;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final marks = dayMarks(period, byDay, now);
    final soFar = [
      for (final m in marks)
        if (m.state != MarkState.future) m.moneyOut,
    ];
    final lead = (period.start.weekday - weekStartsOn) % 7;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final m in marks)
        _DayCell(
          mark: m,
          step: heatStep(m.moneyOut, soFar),
          selected: selected != null && dateOnly(m.start) == selected,
          onTap: m.state == MarkState.future ? null : () => onSelect(m.start),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    // 1 November 2026 is a Sunday; this names each weekday from the person's
                    // chosen start.
                    DateFormat('EEEEE').format(DateTime(2026, 11, 1 + (weekStartsOn + i) % 7)),
                    textAlign: TextAlign.center,
                    style: t.captionStrong.copyWith(color: c.inkMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AkSpace.s2h),
        for (var r = 0; r < cells.length; r += 7) ...[
          if (r > 0) const SizedBox(height: AkSpace.s1),
          Row(
            children: [
              // No gap between the cells here: each cell keeps the drawn 4px gap inside
              // itself, so its tap area spans the gap and stays 44px wide on a 360dp phone.
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: SizedBox(height: AkSize.row, child: cells[r + i]),
                ),
            ],
          ),
        ],
        const SizedBox(height: AkSpace.s2h),
        ExcludeSemantics(
          child: Row(
            children: [
              Text('Less', style: t.caption.copyWith(color: c.inkMuted)),
              for (var s = 0; s < 4; s++) ...[
                const SizedBox(width: AkSpace.s2),
                Container(
                  width: AkSize.iconSm,
                  height: AkSpace.s3,
                  decoration: BoxDecoration(
                    color: _heatColour(c, s),
                    borderRadius: BorderRadius.circular(context.metrics.xs),
                  ),
                ),
              ],
              const SizedBox(width: AkSpace.s2),
              Flexible(
                child: Text(
                  'More, in thousands of UGX',
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.mark,
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final CalendarMark mark;
  final int step;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final future = mark.state == MarkState.future;
    final fill = future ? c.ground.withValues(alpha: 0) : _heatColour(c, step);
    final ink = !future && step == 3 ? c.onHeat4 : c.ink;
    final radius = BorderRadius.circular(context.metrics.md);
    final spoken = future
        ? '${_dayName(mark.start)}, not yet'
        : '${_dayName(mark.start)}, ${formatUgx(mark.moneyOut)} out';

    return Semantics(
      button: !future,
      selected: selected,
      label: spoken,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      // The tap area is the whole cell, gap included; the drawn square sits inside it.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AkSpace.s0h),
          child: _square(c, t, fill, ink, radius, future),
        ),
      ),
    );
  }

  Widget _square(
    AkColorTokens c,
    AkType t,
    Color fill,
    Color ink,
    BorderRadius radius,
    bool future,
  ) {
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: future ? BorderSide(color: c.lineStrong) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          foregroundDecoration: selected
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: c.ink, width: AkSpace.s0h),
                )
              : null,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${mark.start.day}', style: t.figure.copyWith(color: ink)),
                // A day with nothing spent keeps its light fill but no "0"; the
                // spoken label still says UGX 0.
                if (!future && mark.moneyOut > 0)
                  Text(formatShort(mark.moneyOut), style: t.caption.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bars for Week, Quarter and Year: past in a mid step, the current one darkest, and what
/// is still to come as a dashed outline.
class _BarsView extends StatelessWidget {
  const _BarsView({
    required this.marks,
    required this.label,
    required this.markName,
    required this.emptyText,
    this.selected,
    this.onSelect,
    this.footer,
  });

  final List<CalendarMark> marks;
  final String Function(CalendarMark) label;
  final String Function(CalendarMark) markName;
  final String emptyText;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;
  final Widget Function(List<CalendarMark>)? footer;

  @override
  Widget build(BuildContext context) {
    final spent = marks.any((m) => m.moneyOut > 0);
    if (!spent) return _Empty(emptyText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Bars(
          marks: marks,
          label: label,
          markName: markName,
          selected: selected,
          onSelect: onSelect,
        ),
        ?footer?.call(marks),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.marks,
    required this.label,
    required this.markName,
    this.selected,
    this.onSelect,
  });

  final List<CalendarMark> marks;
  final String Function(CalendarMark) label;
  final String Function(CalendarMark) markName;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final max = marks.fold<int>(0, (a, m) => m.moneyOut > a ? m.moneyOut : a);
    final gap = marks.length > 12 ? AkSpace.s0h : AkSpace.s1;
    final radius = context.metrics.xs;

    Widget bar(CalendarMark m) {
      final isSelected = selected != null && dateOnly(m.start) == selected;
      final Widget shape = switch (m.state) {
        // A quarter of the height: present, but never a figure.
        MarkState.future => FractionallySizedBox(
          heightFactor: 0.25,
          alignment: Alignment.bottomCenter,
          child: AkDashedBox(color: c.lineStrong, radius: radius),
        ),
        _ => FractionallySizedBox(
          heightFactor: max == 0 ? 0 : m.moneyOut / max,
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSpace.s0h),
            decoration: BoxDecoration(
              color: m.state == MarkState.current || isSelected ? c.heat4 : c.heat2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            ),
          ),
        ),
      };
      final spoken = m.state == MarkState.future
          ? '${markName(m)}, not yet'
          : '${markName(m)}, ${formatUgx(m.moneyOut)} out';
      final tap = onSelect == null || m.state == MarkState.future ? null : () => onSelect!(m.start);
      return Semantics(
        label: spoken,
        button: tap != null,
        selected: isSelected,
        container: true,
        excludeSemantics: true,
        onTap: tap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: Align(alignment: Alignment.bottomCenter, child: shape),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AkSize.chart,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, m) in marks.indexed) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: bar(m)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AkSpace.s1h),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final (i, m) in marks.indexed) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(
                    label(m),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: (selected != null && dateOnly(m.start) == selected
                        ? t.chartLabel.copyWith(fontWeight: FontWeight.w600, color: c.ink)
                        : t.chartLabel.copyWith(color: c.inkMuted)),
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

/// Day: money out by hour, then the day's entries.
class _DayView extends ConsumerWidget {
  const _DayView({required this.day, required this.rows, required this.now});

  final DateTime day;
  final List<Transaction> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) return const _Empty('Nothing added on this day.');
    final categories = {
      for (final cat in ref.watch(allCategoriesProvider).value ?? const <Category>[]) cat.id: cat,
    };
    final accounts = {
      for (final a in ref.watch(enabledAccountsProvider).value ?? const <Account>[]) a.id: a.name,
    };
    // The time now, not when the app opened: an hour that has begun since then is not
    // "not yet". The view rebuilds whenever an entry is added, so this stays current.
    final hours = hourMarks(day, rows, clock.now());
    final spent = hours.any((h) => h.moneyOut > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spent)
          _Bars(
            marks: hours,
            label: (m) => m.start.hour % 6 == 0 ? DateFormat('HH').format(m.start) : '',
            markName: (m) => 'From ${DateFormat('HH:mm').format(m.start)}',
          ),
        const SizedBox(height: AkSpace.s4),
        for (final tx in rows)
          TransactionRow(
            transaction: tx,
            now: now,
            category: categories[tx.categoryId],
            accountName: accounts[tx.accountId] ?? '',
            toAccountName: tx.toAccountId == null ? null : accounts[tx.toAccountId],
            onTap: () => context.push(Routes.transaction(tx.id)),
          ),
      ],
    );
  }
}

/// The highest, lowest and usual month, once two months have ended.
class _YearFacts extends StatelessWidget {
  const _YearFacts({required this.summary});

  final YearSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) {
      return const _Caption('The highest, lowest and usual month appear once two months end.');
    }
    String month(CalendarMark m) => DateFormat('MMMM').format(m.start);
    return Padding(
      padding: const EdgeInsets.only(top: AkSpace.s4),
      child: AkCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _Fact('Highest month', '${month(s.highest)}, ${formatUgx(s.highest.moneyOut)}'),
            _Fact('Lowest month', '${month(s.lowest)}, ${formatUgx(s.lowest.moneyOut)}'),
            _Fact('Usual month', formatUgx(s.usual), last: true),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      label: '$label, $value',
      container: true,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AkSize.row),
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: t.bodySm.copyWith(color: c.inkMuted)),
            ),
            const SizedBox(width: AkSpace.s3),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: t.bodyStrong.copyWith(color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chosen day's total, and a way into that day's entries.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.amount, required this.onOpen});

  final DateTime day;
  final int amount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    return Semantics(
      button: true,
      label: '${_dayName(day)}, ${formatUgx(amount)} out. See that day',
      container: true,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSize.nav),
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h, vertical: AkSpace.s2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayName(day), style: t.caption.copyWith(color: c.inkMuted)),
                      Text(formatUgx(amount), style: t.displaySm.copyWith(color: c.ink)),
                    ],
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Text('See that day', style: t.bodyStrong.copyWith(color: c.brandText)),
                const SizedBox(width: AkSpace.s1),
                AkIcon(AkIcons.chevron, color: c.brandText, size: AkSize.iconSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => AkCard(
    child: Text(text, style: context.type.bodySm.copyWith(color: context.colors.inkMuted)),
  );
}
