import 'package:intl/intl.dart';

import '../../core/format/money.dart';
import '../../core/time/period.dart';

/// "1 to 19 November", or "30 November to 6 December" across a month end.
String rangeText(DateTime first, DateTime last) => first.month == last.month
    ? '${first.day} to ${DateFormat('d MMMM').format(last)}'
    : '${DateFormat('d MMMM').format(first)} to ${DateFormat('d MMMM').format(last)}';

/// What a previous period is called in a sentence, such as "on October".
String againstWord(PeriodKind kind, Period previous) => switch (kind) {
  PeriodKind.week => 'last week',
  PeriodKind.quarter => 'the three months before',
  PeriodKind.year => '${previous.start.year}',
  _ => DateFormat('MMMM').format(previous.start),
};

/// The one-sentence reading under a comparison: "Up 12% on October for the same days."
String comparisonReading(int? percent, String against) {
  if (percent == null) return 'Nothing to compare with yet.';
  if (percent == 0) return 'Level with $against for the same days.';
  final word = percent > 0 ? 'Up' : 'Down';
  return '$word ${formatPercent(percent.abs().toDouble())} on $against for the same days.';
}
