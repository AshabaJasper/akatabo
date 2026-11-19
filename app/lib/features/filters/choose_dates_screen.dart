import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/providers.dart';
import '../../domain/date_choice.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import 'date_choice_providers.dart';

String _label(DatePreset p) => switch (p) {
  DatePreset.last7Days => 'Last 7 days',
  DatePreset.thisMonth => 'This month',
  DatePreset.lastMonth => 'Last month',
  DatePreset.last3Months => 'Last 3 months',
  DatePreset.thisYear => 'This year',
  DatePreset.custom => 'Custom',
};

final _shortDate = DateFormat('d MMM yyyy');
final _spokenDay = DateFormat('EEEE d MMMM yyyy');

/// Choose dates: a preset, or a custom range picked on a month grid. The choice is applied
/// with the button at the foot, and then held by [dateChoiceProvider].
class ChooseDatesScreen extends ConsumerStatefulWidget {
  const ChooseDatesScreen({super.key});

  @override
  ConsumerState<ChooseDatesScreen> createState() => _ChooseDatesScreenState();
}

class _ChooseDatesScreenState extends ConsumerState<ChooseDatesScreen> {
  late DatePreset _preset;
  late DateTime _first;
  late DateTime _last;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final period = ref.read(chosenPeriodProvider);
    _preset = ref.read(dateChoiceProvider).preset;
    _first = period.start;
    _last = period.lastDate;
    _month = DateTime(_last.year, _last.month);
  }

  void _choose(DatePreset p) {
    setState(() {
      _preset = p;
      if (p == DatePreset.custom) return;
      final period = presetPeriod(p, ref.read(appNowProvider), ref.read(periodCalculatorProvider));
      _first = period.start;
      _last = period.lastDate;
      _month = DateTime(_last.year, _last.month);
    });
  }

  void _tapDay(DateTime day) {
    final picked = pickDay(_first, _last, day);
    setState(() {
      _preset = DatePreset.custom;
      _first = picked.first;
      _last = picked.last;
    });
  }

  Future<void> _apply() async {
    final notifier = ref.read(dateChoiceProvider.notifier);
    if (_preset == DatePreset.custom) {
      notifier.chooseCustom(_first, _last);
    } else {
      notifier.choosePreset(_preset);
    }
    await closeScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final calc = ref.watch(periodCalculatorProvider);
    final today = ref.watch(appNowProvider);
    final isCustom = _preset == DatePreset.custom;
    final days = isCustom
        ? inclusiveDays(_first, _last)
        : presetPeriod(_preset, today, calc).lengthInDays;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Filters', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s4),
            Semantics(header: true, child: Text('Choose dates', style: t.displayLg)),
            const SizedBox(height: AkSpace.s4),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                for (final p in DatePreset.values)
                  AkChip(label: _label(p), selected: p == _preset, onTap: () => _choose(p)),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            if (isCustom) ...[
              Text('From ${_shortDate.format(_first)}', style: t.bodyMd),
              Text('To ${_shortDate.format(_last)}', style: t.bodyMd),
              const SizedBox(height: AkSpace.s4),
              _MonthGrid(
                month: _month,
                first: _first,
                last: _last,
                weekStartsOn: calc.weekStartsOn,
                onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                onTapDay: _tapDay,
              ),
              const SizedBox(height: AkSpace.s3),
              Text(
                'Tap the first day, then the last day. A third tap starts again.',
                style: t.bodySm.copyWith(color: c.inkMuted),
              ),
            ] else
              Text(
                '${_shortDate.format(_first)} to ${_shortDate.format(_last)}',
                style: t.bodyMd.copyWith(color: c.inkMuted),
              ),
            const SizedBox(height: AkSpace.s6),
            AkPrimaryButton(
              label: days == 1 ? 'Show this day' : 'Show these $days days',
              onPressed: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

/// One month as a grid of days, weeks starting on the person's chosen day. Days in the range
/// are tinted; the two ends are darkest.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.first,
    required this.last,
    required this.weekStartsOn,
    required this.onPrevious,
    required this.onNext,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime first;
  final DateTime last;
  final int weekStartsOn;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final lead = (DateTime(month.year, month.month).weekday - weekStartsOn) % 7;
    final count = daysInMonth(month.year, month.month);
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++)
        _DayCell(
          day: DateTime(month.year, month.month, d),
          first: first,
          last: last,
          onTap: onTapDay,
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepButton(
              icon: AkIcons.chevron,
              label: 'Previous month',
              onTap: onPrevious,
              back: true,
            ),
            Expanded(
              child: Center(
                child: Text(DateFormat('MMMM yyyy').format(month), style: t.bodyStrong),
              ),
            ),
            _StepButton(icon: AkIcons.chevron, label: 'Next month', onTap: onNext),
          ],
        ),
        const SizedBox(height: AkSpace.s2),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    // 1 November 2026 is a Sunday; this names each weekday from the chosen start.
                    DateFormat('EEEEE').format(DateTime(2026, 11, 1 + (weekStartsOn + i) % 7)),
                    textAlign: TextAlign.center,
                    style: t.captionStrong.copyWith(color: c.inkMuted),
                  ),
                ),
            ],
          ),
        ),
        for (var r = 0; r < cells.length; r += 7)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: SizedBox(height: AkSize.target, child: cells[r + i]),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.first, required this.last, required this.onTap});

  final DateTime day;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final d = dateOnly(day);
    final isEnd = d == first || d == last;
    final inRange = !d.isBefore(first) && !d.isAfter(last);
    final radius = BorderRadius.circular(context.metrics.md);

    return Semantics(
      button: true,
      selected: inRange,
      label: _spokenDay.format(d),
      container: true,
      excludeSemantics: true,
      onTap: () => onTap(d),
      child: InkResponse(
        onTap: () => onTap(d),
        radius: AkSize.target / 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isEnd ? c.brand : (inRange ? c.rangeBand : null),
            borderRadius: radius,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${d.day}', style: t.bodyMd.copyWith(color: isEnd ? c.onBrand : c.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.back = false,
  });

  final AkIcons icon;
  final String label;
  final VoidCallback onTap;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final glyph = AkIcon(icon, color: c.ink, size: AkSize.iconSm);
    return Semantics(
      button: true,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: AkSize.target / 2,
        child: SizedBox.square(
          dimension: AkSize.target,
          child: Center(child: back ? RotatedBox(quarterTurns: 2, child: glyph) : glyph),
        ),
      ),
    );
  }
}
