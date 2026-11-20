import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/forecast_snapshot_repository.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/forecast.dart';
import '../../domain/spending.dart';
import '../../smart/forecast/forecast_range.dart';
import '../home/home_providers.dart';
import '../regular/regular_providers.dart';

// Written by hand: it names drift's generated row class (see add_providers.dart).

/// Every entry in the rate window, which is the last [rateWindowDays] days up to today.
/// Closes its watch when the day changes, so the window moves on at midnight.
final forecastWindowRowsProvider = StreamProvider.autoDispose<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchIn(rateWindow(ref.watch(appNowProvider))),
);

final forecastSnapshotRepositoryProvider = Provider<ForecastSnapshotRepository>(
  (ref) => ForecastSnapshotRepository(ref.watch(appDatabaseProvider)),
);

/// The [forecastMaxMonths] months before the current one, newest first.
final forecastPastMonthsProvider = Provider.autoDispose<List<Period>>((ref) {
  final calc = ref.watch(periodCalculatorProvider);
  var month = ref.watch(currentMonthProvider);
  return [for (var i = 0; i < forecastMaxMonths; i++) month = calc.month(addDays(month.start, -1))];
});

/// Forecasts saved in the earlier months, kept current.
final forecastPastSnapshotsProvider = StreamProvider.autoDispose<List<ForecastSnapshot>>((ref) {
  final past = ref.watch(forecastPastMonthsProvider);
  return ref
      .watch(forecastSnapshotRepositoryProvider)
      .watchBetween(
        sinceDay: toLocalDay(past.last.start),
        beforeDay: toLocalDay(ref.watch(currentMonthProvider).start),
      );
});

/// Every entry in the earlier months, to tell what each month really came to.
final forecastPastRowsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final past = ref.watch(forecastPastMonthsProvider);
  final current = ref.watch(currentMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchIn(Period(past.last.start, current.start, PeriodKind.custom));
});

/// How far the person's own earlier forecasts were out, one error per earlier month with a
/// saved forecast, newest first. Empty when no month has one. Null while still loading.
final forecastSnapshotErrorsProvider = Provider.autoDispose<List<double>?>((ref) {
  final snapsAsync = ref.watch(forecastPastSnapshotsProvider);
  if (snapsAsync.hasError) return const [];
  final snaps = snapsAsync.value;
  if (snaps == null) return null;
  if (snaps.isEmpty) return const [];

  final rowsAsync = ref.watch(forecastPastRowsProvider);
  if (rowsAsync.hasError) return const [];
  final rows = rowsAsync.value;
  if (rows == null) return null;

  final current = ref.watch(currentMonthProvider);
  final today = dateOnly(ref.watch(appNowProvider));
  return snapshotErrors(
    pastSnapshotPoints(snaps, rows, ref.watch(forecastPastMonthsProvider)),
    dayInPeriod: daysBetween(current.start, today) + 1,
  );
});

/// Each saved forecast of an earlier month next to what that month really came to. A snapshot
/// whose month no longer lines up with a month (after "Month starts on" changed) is left out.
List<SnapshotPoint> pastSnapshotPoints(
  List<ForecastSnapshot> snaps,
  List<Transaction> rows,
  List<Period> months,
) {
  final actual = <int, int>{
    for (final m in months)
      toLocalDay(m.start): totalsOf(
        rows.where((t) => t.localDay >= toLocalDay(m.start) && t.localDay < toLocalDay(m.end)),
      ).moneyOut,
  };
  return [
    for (final s in snaps)
      if (actual[s.periodStart] case final total?)
        SnapshotPoint(
          periodStart: s.periodStart,
          dayInPeriod: daysBetween(fromLocalDay(s.periodStart), fromLocalDay(s.takenOn)) + 1,
          point: s.point,
          actual: total,
        ),
  ];
}

/// The forecast for the current month as the screens show it.
class MonthForecastView {
  const MonthForecastView({
    required this.ready,
    required this.daysWithEntries,
    this.forecast,
    this.range,
  });

  /// Whether every input has loaded.
  final bool ready;

  /// Days this month with at least one entry, for "4 more to go".
  final int daysWithEntries;

  /// The Phase 3 forecast, or null before [forecastMinDays] days have entries.
  final Forecast? forecast;

  /// The range around it, or null when there is no forecast or "Forecast the month" is off.
  final ForecastRange? range;
}

/// The current month's forecast and its range, from the person's own entries.
final monthForecastProvider = Provider.autoDispose<MonthForecastView>((ref) {
  final today = dateOnly(ref.watch(appNowProvider));
  final month = ref.watch(currentMonthProvider);
  final monthAsync = ref.watch(monthRowsProvider);
  final windowAsync = ref.watch(forecastWindowRowsProvider);
  final regularAsync = ref.watch(activeRegularProvider);
  final monthRows = monthAsync.value ?? const <Transaction>[];
  final daysWithEntries = {for (final t in monthRows) t.localDay}.length;
  final ready = monthAsync.hasValue && windowAsync.hasValue && regularAsync.hasValue;
  if (!ready) return MonthForecastView(ready: false, daysWithEntries: daysWithEntries);

  final forecast = forecastFor(
    month: month,
    today: today,
    monthRows: monthRows,
    windowRows: windowAsync.value ?? const [],
    regular: regularAsync.value ?? const [],
  );
  final smartOn = SettingKeys.forecastMonth.decode(
    ref.watch(storedSettingsProvider).value?[SettingKeys.forecastMonth.name],
  );
  if (forecast == null || !smartOn) {
    return MonthForecastView(ready: true, daysWithEntries: daysWithEntries, forecast: forecast);
  }

  final errors = ref.watch(forecastSnapshotErrorsProvider);
  if (errors == null) {
    // Wait for the track record rather than show a range that moves a moment later.
    return MonthForecastView(ready: false, daysWithEntries: daysWithEntries);
  }
  final range = forecastRange(
    spentSoFar: forecast.spentSoFar,
    everydayDaily: forecast.everydayDaily,
    spentToday: forecast.everydayToday,
    daysLeft: forecast.daysLeft,
    regular: [
      for (final b in forecast.regularBands)
        RegularBand(low: b.low, typical: b.typical, high: b.high),
    ],
    dayOfMonth: today.day,
    snapshotErrors: errors,
  );
  return MonthForecastView(
    ready: true,
    daysWithEntries: daysWithEntries,
    forecast: forecast,
    range: range,
  );
});

/// Saves the first forecast and range shown each day, so later months can learn how close it
/// came. Each day is written once per app run; the table keeps only the first anyway.
class ForecastSnapshotSaver {
  ForecastSnapshotSaver(this._write);

  final Future<void> Function({
    required int periodStart,
    required int takenOn,
    required int point,
    required int low,
    required int high,
    required int spentSoFar,
  })
  _write;
  final _saved = <(int, int)>{};

  /// Remembers [range] as shown on [today] for the month starting [monthStart]. Safe to call on
  /// every build: only the first call for a day writes.
  void remember({
    required DateTime monthStart,
    required DateTime today,
    required ForecastRange range,
    required int spentSoFar,
  }) {
    final key = (toLocalDay(monthStart), toLocalDay(today));
    if (!_saved.add(key)) return;
    unawaited(
      _write(
        periodStart: key.$1,
        takenOn: key.$2,
        point: range.point,
        low: range.low,
        high: range.high,
        spentSoFar: spentSoFar,
      ).catchError((Object _) {
        // A snapshot that fails to save only means one month less to learn from. Let the next
        // showing try again.
        _saved.remove(key);
      }),
    );
  }
}

final forecastSnapshotSaverProvider = Provider<ForecastSnapshotSaver>(
  (ref) => ForecastSnapshotSaver(ref.watch(forecastSnapshotRepositoryProvider).saveFirstOfDay),
);
