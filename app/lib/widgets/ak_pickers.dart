import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import 'ak_month_grid.dart';

/// The pickers behind value rows: a date dialog, a time dialog, both in a row, and a sheet
/// that picks one value from a list. None of them is drawn in the design; they are built from
/// the rules in DESIGN_SYSTEM.md and flagged for a design check.
///
/// The date dialog is the app's own month grid ([AkMonthGrid]), not Material's: Material's
/// calendar draws its arrows from the Material icon font, which the app does not bundle (every
/// icon is an [AkIcon] vector), so its arrows showed as empty boxes. The time dialog is
/// Material's, in typing mode only, which has no icon at all.

/// Gives Material's time dialog the app's colours, corners and 24-hour clock. Pass it as the
/// `builder` of `showTimePicker`.
Widget akPickerBuilder(BuildContext context, Widget? child) {
  final c = context.colors;
  final t = context.type;
  final m = context.metrics;
  final base = Theme.of(context);
  final buttonStyle = TextButton.styleFrom(
    foregroundColor: c.brandText,
    textStyle: t.button,
    minimumSize: const Size(AkSize.target, AkSize.target),
  );

  // The time dialog takes plain colours that change with state.
  Color chosenColour(Color on, Color off) =>
      WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? on : off);

  return Theme(
    data: base.copyWith(
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.lg),
          side: BorderSide(color: c.line),
        ),
        helpTextStyle: t.eyebrow.copyWith(color: c.inkMuted),
        // The part being set (hour or minute) is filled with the brand colour, as a chosen
        // day is; the other sits on the sunken surface.
        hourMinuteColor: chosenColour(c.brand, c.surfaceSunk),
        hourMinuteTextColor: chosenColour(c.onBrand, c.ink),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(m.md)),
        dialBackgroundColor: c.surfaceSunk,
        dialHandColor: c.brand,
        dialTextColor: chosenColour(c.onBrand, c.ink),
        dialTextStyle: t.body,
        dayPeriodColor: c.brand,
        dayPeriodTextColor: chosenColour(c.onBrand, c.ink),
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
    ),
    // The app writes times as 09:14 everywhere, so the dialog uses the 24-hour clock too.
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Asks for a day between [first] and [last]. Returns the day at midnight, or null.
Future<DateTime?> showAkDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
  int weekStartsOn = DateTime.sunday,
}) {
  final from = _day(first);
  final to = _day(last);
  var start = _day(initial);
  if (start.isBefore(from)) start = from;
  if (start.isAfter(to)) start = to;
  return showDialog<DateTime>(
    context: context,
    builder: (_) => AkDateDialog(
      initial: start,
      first: from,
      last: to,
      // The app's clock, not the device's, so tests and the ring around today agree with
      // the rest of the app.
      today: _day(clock.now()),
      helpText: helpText ?? 'Choose the day',
      weekStartsOn: weekStartsOn,
    ),
  );
}

/// The date dialog: the chosen day written out, a month grid, Cancel and OK.
class AkDateDialog extends StatefulWidget {
  const AkDateDialog({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
    required this.today,
    required this.helpText,
    this.weekStartsOn = DateTime.sunday,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final String helpText;
  final int weekStartsOn;

  @override
  State<AkDateDialog> createState() => _AkDateDialogState();
}

class _AkDateDialogState extends State<AkDateDialog> {
  static final _headline = DateFormat('EEE d MMM');

  late DateTime _chosen = widget.initial;
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  bool get _canGoBack => _month.isAfter(DateTime(widget.first.year, widget.first.month));
  bool get _canGoOn => _month.isBefore(DateTime(widget.last.year, widget.last.month));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final m = context.metrics;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: c.brandText,
      textStyle: t.button,
      minimumSize: const Size(AkSize.target, AkSize.target),
    );
    return Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: AkSpace.s5, vertical: AkSpace.s6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.lg),
        side: BorderSide(color: c.line),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AkSpace.s5, AkSpace.s5, AkSpace.s5, AkSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.helpText.toUpperCase(), style: t.eyebrow.copyWith(color: c.inkMuted)),
            const SizedBox(height: AkSpace.s1),
            Semantics(
              liveRegion: true,
              child: Text(_headline.format(_chosen), style: t.displaySm.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s4),
            AkMonthGrid(
              month: _month,
              first: _chosen,
              last: _chosen,
              weekStartsOn: widget.weekStartsOn,
              earliest: widget.first,
              latest: widget.last,
              today: widget.today,
              onPrevious: _canGoBack
                  ? () => setState(() => _month = DateTime(_month.year, _month.month - 1))
                  : null,
              onNext: _canGoOn
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
              onTapDay: (d) => setState(() => _chosen = d),
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: buttonStyle,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AkSpace.s2),
                TextButton(
                  style: buttonStyle,
                  onPressed: () => Navigator.of(context).pop(_chosen),
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a time of day on the 24-hour clock, typed as hours and minutes. Returns null when
/// cancelled.
Future<TimeOfDay?> showAkTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? helpText,
}) => showTimePicker(
  context: context,
  initialTime: initial,
  helpText: helpText,
  // Typing only: no switch to the dial, whose button is a Material font icon, and two number
  // fields are quicker and clearer for a screen reader than a dial.
  initialEntryMode: TimePickerEntryMode.inputOnly,
  builder: akPickerBuilder,
);

/// Asks for a day, then a time on that day. Returns the local moment, or null when either
/// step is cancelled. It does not judge the moment: callers decide what is allowed.
Future<DateTime?> showAkDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String dateHelp = 'Choose the day',
  String timeHelp = 'Choose the time',
  int weekStartsOn = DateTime.sunday,
}) async {
  final day = await showAkDatePicker(
    context,
    initial: initial,
    first: first,
    last: last,
    helpText: dateHelp,
    weekStartsOn: weekStartsOn,
  );
  if (day == null || !context.mounted) return null;
  final time = await showAkTimePicker(
    context,
    initial: TimeOfDay.fromDateTime(initial),
    helpText: timeHelp,
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// A sheet that asks the person to choose one of [options] and returns the chosen value, or
/// null when it is dismissed. The current value is ticked and scrolled into view.
///
/// [note] is an optional plain sentence under the title, for example why a list is short.
Future<T?> showAkChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? note,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => _ChoiceSheet<T>(title: title, options: options, selected: selected, note: note),
);

class _ChoiceSheet<T> extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.note,
  });

  final String title;
  final List<(T, String)> options;
  final T? selected;
  final String? note;

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A long list (28 month days) would otherwise open with the current value out of sight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s2),
            child: Semantics(
              header: true,
              child: Text(widget.title, style: t.title.copyWith(color: c.ink)),
            ),
          ),
          if (widget.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s2),
              child: Text(widget.note!, style: t.bodySm.copyWith(color: c.inkMuted)),
            ),
          Flexible(
            // Every row is built (a lazy list would not build a value far down, so it could
            // not be scrolled to); the lists here are short, 28 rows at most.
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AkSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (value, label) in widget.options)
                    _ChoiceRow(
                      key: value == widget.selected ? _selectedKey : null,
                      label: label,
                      selected: value == widget.selected,
                      onTap: () => Navigator.of(context).pop(value),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSize.row),
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6, vertical: AkSpace.s2),
            color: selected ? c.surfaceSunk : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: (selected ? t.bodyStrong : t.bodyMd).copyWith(color: c.ink),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AkSpace.s3),
                  AkIcon(AkIcons.check, color: c.brandText),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
