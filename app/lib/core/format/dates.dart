/// How a full date is written, from "Date style" in General settings.
library;

import 'package:intl/intl.dart';

/// "Date style": in words (each screen's own wording, such as `19 Nov 2026` or
/// `19 November 2026`), day first in numbers, or year first.
enum DateStyle {
  words('19 Nov 2026'),
  dayFirst('19/11/2026'),
  yearFirst('2026-11-19');

  const DateStyle(this.example);

  /// The style shown as itself, for the choice list and the settings row.
  final String example;
}

/// [day] in [style]. Under [DateStyle.words] it follows [words], the screen's own pattern,
/// so the default changes nothing anyone has seen; the number styles are the same everywhere.
String formatDate(DateTime day, DateStyle style, {String words = 'd MMM y'}) =>
    DateFormat(switch (style) {
      DateStyle.words => words,
      DateStyle.dayFirst => 'dd/MM/y',
      DateStyle.yearFirst => 'y-MM-dd',
    }).format(day);
