import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../data/providers.dart';
import '../../domain/date_choice.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_month_grid.dart';
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

  /// "All dates" is picked: no day limit at all. Applying it clears the date choice.
  late bool _allDates;

  @override
  void initState() {
    super.initState();
    _allDates = ref.read(dateChoiceProvider) == null;
    // With all dates chosen, the screen opens on This month: the first range a person picks
    // from is the one they can see on the calendar.
    final period =
        ref.read(chosenPeriodProvider) ??
        presetPeriod(
          DatePreset.thisMonth,
          ref.read(appNowProvider),
          ref.read(periodCalculatorProvider),
        );
    _preset = ref.read(dateChoiceProvider)?.preset ?? DatePreset.thisMonth;
    _first = period.start;
    _last = period.lastDate;
    _month = DateTime(_last.year, _last.month);
  }

  void _chooseAllDates() => setState(() => _allDates = true);

  void _choose(DatePreset p) {
    setState(() {
      _allDates = false;
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
      _allDates = false;
      _preset = DatePreset.custom;
      _first = picked.first;
      _last = picked.last;
    });
  }

  Future<void> _apply() async {
    final notifier = ref.read(dateChoiceProvider.notifier);
    if (_allDates) {
      notifier.clear();
    } else if (_preset == DatePreset.custom) {
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
    final buttonLabel = _allDates
        ? 'Show all transactions'
        : days == 1
        ? 'Show this day'
        : 'Show these $days days';

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
                AkChip(label: 'All dates', selected: _allDates, onTap: _chooseAllDates),
                for (final p in DatePreset.values)
                  AkChip(
                    label: _label(p),
                    selected: !_allDates && p == _preset,
                    onTap: () => _choose(p),
                  ),
              ],
            ),
            const SizedBox(height: AkSpace.s4),
            if (_allDates)
              Text('Every entry, whatever its date.', style: t.bodyMd.copyWith(color: c.inkMuted))
            else if (isCustom) ...[
              Text('From ${_shortDate.format(_first)}', style: t.bodyMd),
              Text('To ${_shortDate.format(_last)}', style: t.bodyMd),
              const SizedBox(height: AkSpace.s4),
              AkMonthGrid(
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
            AkPrimaryButton(label: buttonLabel, onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
