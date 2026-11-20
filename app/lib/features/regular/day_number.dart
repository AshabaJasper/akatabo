/// Day numbers for the smart detectors: whole days since 1 January 1970, counted on the
/// calendar date alone so daylight saving and time zones cannot shift them.
library;

int dayNumberOf(int localDay) => DateTime.utc(
  localDay ~/ 10000,
  localDay ~/ 100 % 100,
  localDay % 100,
).difference(DateTime.utc(1970)).inDays;

/// The yyyymmdd local day for a day number.
int localDayOfNumber(int dayNumber) {
  final d = DateTime.utc(1970).add(Duration(days: dayNumber));
  return d.year * 10000 + d.month * 100 + d.day;
}
