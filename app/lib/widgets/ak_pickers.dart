import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';

/// The pickers behind value rows: a date picker, a time picker, both in a row, and a sheet
/// that picks one value from a list. None of them is drawn in the design; they are built from
/// the rules in DESIGN_SYSTEM.md and flagged for a design check.
///
/// Material's own date and time dialogs are used, dressed in the app's tokens so they match
/// the light and dark themes instead of looking like stock Material, and writing dates the
/// way the rest of the app does ("Thu 19 Nov", 19/11/2026, the 24-hour clock).

/// Gives a Material date or time dialog the app's colours, corners, date words and 24-hour
/// clock. Pass it as the `builder` of `showDatePicker` or `showTimePicker` called anywhere
/// else in the app, so every picker looks the same. Weeks start on Sunday, as drawn; use
/// [akPickerBuilderFor] to follow the person's "Week starts on".
Widget akPickerBuilder(BuildContext context, Widget? child) => akPickerBuilderFor()(context, child);

/// [akPickerBuilder] with the calendar's first column set to [weekStartsOn]
/// ([DateTime.monday] to [DateTime.sunday]).
TransitionBuilder akPickerBuilderFor({int weekStartsOn = DateTime.sunday}) =>
    (context, child) => _themed(context, weekStartsOn, child);

Widget _themed(BuildContext context, int weekStartsOn, Widget? child) {
  final c = context.colors;
  final t = context.type;
  final m = context.metrics;
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(m.lg),
    side: BorderSide(color: c.line),
  );
  final buttonStyle = TextButton.styleFrom(
    foregroundColor: c.brandText,
    textStyle: t.button,
    minimumSize: const Size(AkSize.target, AkSize.target),
  );

  WidgetStateProperty<Color?> chosen(Color on, Color off, {Color? disabled}) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return disabled;
        return states.contains(WidgetState.selected) ? on : off;
      });

  // The time dialog takes plain colours that change with state.
  Color chosenColour(Color on, Color off) =>
      WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? on : off);

  // Days before the earliest or after the latest date are shown faded but still readable.
  final faded = c.inkMuted.withValues(alpha: 0.6);
  final clear = c.surface.withValues(alpha: 0);

  return Theme(
    data: base.copyWith(
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: c.surface,
        elevation: 0,
        shape: shape,
        headerBackgroundColor: c.surface,
        headerForegroundColor: c.ink,
        headerHelpStyle: t.eyebrow.copyWith(color: c.inkMuted),
        headerHeadlineStyle: t.displaySm.copyWith(color: c.ink),
        weekdayStyle: t.caption.copyWith(color: c.inkMuted),
        dayStyle: t.body,
        dividerColor: c.line,
        dayForegroundColor: chosen(c.onBrand, c.ink, disabled: faded),
        dayBackgroundColor: chosen(c.brand, clear),
        dayOverlayColor: WidgetStatePropertyAll(c.brand.withValues(alpha: 0.08)),
        todayForegroundColor: chosen(c.onBrand, c.brandText, disabled: faded),
        todayBackgroundColor: chosen(c.brand, clear),
        todayBorder: BorderSide(color: c.brand),
        yearForegroundColor: chosen(c.onBrand, c.ink, disabled: faded),
        yearBackgroundColor: chosen(c.brand, clear),
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: shape,
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
        entryModeIconColor: c.inkMuted,
        dayPeriodColor: c.brand,
        dayPeriodTextColor: chosenColour(c.onBrand, c.ink),
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
    ),
    child: Localizations.override(
      context: context,
      delegates: [_AkPickerWordsDelegate(weekStartsOn)],
      // The app writes times as 09:14 everywhere, so the dial uses the 24-hour clock too.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

/// Material's English words with the app's date order: "Thu 19 Nov" in the header,
/// day/month/year when a date is typed, and the person's first day of the week. The app
/// has no other localisations (English only), so this replaces the American defaults.
class _AkPickerWords extends DefaultMaterialLocalizations {
  const _AkPickerWords(this.weekStartsOn);

  final int weekStartsOn;

  static final _medium = DateFormat('EEE d MMM');
  static final _full = DateFormat('EEEE d MMMM y');
  static final _compact = DateFormat('dd/MM/yyyy');

  @override
  int get firstDayOfWeekIndex => weekStartsOn % 7; // Material counts Sunday as 0.

  @override
  String formatMediumDate(DateTime date) => _medium.format(date);

  @override
  String formatFullDate(DateTime date) => _full.format(date);

  @override
  String formatCompactDate(DateTime date) => _compact.format(date);

  @override
  String get dateHelpText => 'dd/mm/yyyy';

  @override
  DateTime? parseCompactDate(String? inputString) {
    final parts = inputString?.trim().split('/');
    if (parts == null || parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || mo == null || y == null || parts[2].length != 4) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > DateUtils.getDaysInMonth(y, mo)) return null;
    return DateTime(y, mo, d);
  }
}

class _AkPickerWordsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _AkPickerWordsDelegate(this.weekStartsOn);

  final int weekStartsOn;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(_AkPickerWords(weekStartsOn));

  @override
  bool shouldReload(_AkPickerWordsDelegate old) => old.weekStartsOn != weekStartsOn;
}

/// Asks for a day between [first] and [last]. Returns the day at midnight, or null.
Future<DateTime?> showAkDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
  int weekStartsOn = DateTime.sunday,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final from = day(first);
  final to = day(last);
  var start = day(initial);
  if (start.isBefore(from)) start = from;
  if (start.isAfter(to)) start = to;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: from,
    lastDate: to,
    // Material reads the device clock for "today"; the app's clock keeps tests and the
    // ring around today in step with the rest of the app.
    currentDate: day(clock.now()),
    helpText: helpText,
    builder: akPickerBuilderFor(weekStartsOn: weekStartsOn),
  );
}

/// Asks for a time of day on the 24-hour clock. Returns null when cancelled.
Future<TimeOfDay?> showAkTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? helpText,
}) => showTimePicker(
  context: context,
  initialTime: initial,
  helpText: helpText,
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
