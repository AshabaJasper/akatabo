import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The month-end forecasts as they were shown, one per day, so the forecast range can learn
/// from how close earlier forecasts came, and "How close it has been" reports what was really
/// forecast rather than a recalculation.
class ForecastSnapshotRepository {
  ForecastSnapshotRepository(this._db);
  final AppDatabase _db;

  /// Saved forecasts for months that started on or after [sinceDay] (yyyymmdd) and before
  /// [beforeDay], kept current.
  Stream<List<ForecastSnapshot>> watchBetween({required int sinceDay, required int beforeDay}) =>
      (_db.select(_db.forecastSnapshots)..where(
            (s) =>
                s.periodStart.isBiggerOrEqualValue(sinceDay) &
                s.periodStart.isSmallerThanValue(beforeDay),
          ))
          .watch();

  /// Keeps the first forecast shown on [takenOn]; a later one that day is not saved, so the
  /// snapshot is what the person saw in the morning, as the backtest assumes.
  Future<void> saveFirstOfDay({
    required int periodStart,
    required int takenOn,
    required int point,
    required int low,
    required int high,
    required int spentSoFar,
  }) => _db
      .into(_db.forecastSnapshots)
      .insert(
        ForecastSnapshotsCompanion.insert(
          periodStart: periodStart,
          takenOn: takenOn,
          point: point,
          low: low,
          high: high,
          spentSoFar: spentSoFar,
          createdAt: clock.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}
