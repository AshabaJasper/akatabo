import 'package:intl/intl.dart';

/// How Add names the moment of an entry: "Today, 09:14", "Yesterday, 18:40",
/// "Tuesday 17 November, 14:30", and with the year when it is not this year.
///
/// [today] is any moment on the person's current day (Africa/Kampala local time).
String whenLabel(DateTime when, DateTime today) {
  final time = DateFormat('HH:mm').format(when);
  return switch (daysBefore(when, today)) {
    0 => 'Today, $time',
    1 => 'Yesterday, $time',
    _ when when.year == today.year => '${DateFormat('EEEE d MMMM').format(when)}, $time',
    _ => '${DateFormat('EEEE d MMMM y').format(when)}, $time',
  };
}

/// Whole calendar days from [when]'s day to [today]'s day; 1 means yesterday.
int daysBefore(DateTime when, DateTime today) => DateTime.utc(
  today.year,
  today.month,
  today.day,
).difference(DateTime.utc(when.year, when.month, when.day)).inDays;

/// The earliest day an entry can be dated: 1 January of last year.
///
/// That reaches back past every period the app compares with (a year against the year
/// before, six months of budget history, ninety days for the forecast) and keeps a slip of
/// the year wheel from filing an entry decades ago.
DateTime earliestEntryDay(DateTime today) => DateTime(today.year - 1);
