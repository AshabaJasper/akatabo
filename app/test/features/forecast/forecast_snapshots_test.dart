import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/forecast_snapshot_repository.dart';
import 'package:akatabo/features/forecast/forecast_providers.dart';
import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

const _range = ForecastRange(
  low: 900000,
  point: 1000000,
  high: 1200000,
  everydayLow: 0,
  everydayHigh: 0,
  monthsUsed: 0,
);

ForecastSnapshot _snap(int periodStart, int takenOn, int point) => ForecastSnapshot(
  periodStart: periodStart,
  takenOn: takenOn,
  point: point,
  low: point,
  high: point,
  spentSoFar: 0,
  createdAt: DateTime(2026),
);

void main() {
  group('the snapshot repository', () {
    late AppDatabase db;
    late ForecastSnapshotRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ForecastSnapshotRepository(db);
    });
    tearDown(() => db.close());

    Future<void> save(int point) => repo.saveFirstOfDay(
      periodStart: 20261101,
      takenOn: 20261119,
      point: point,
      low: point,
      high: point,
      spentSoFar: 0,
    );

    test('keeps the first forecast of a day', () async {
      await save(100);
      await save(200);
      final rows = await repo.watchBetween(sinceDay: 20261101, beforeDay: 20261201).first;
      expect(rows.single.point, 100);
    });

    test('reads only the months asked for', () async {
      await save(100);
      expect(await repo.watchBetween(sinceDay: 20251101, beforeDay: 20261101).first, isEmpty);
    });
  });

  test('the saver writes each day once, and again after a failed write', () async {
    final writes = <int>[];
    var fail = true;
    final saver = ForecastSnapshotSaver(({
      required periodStart,
      required takenOn,
      required point,
      required low,
      required high,
      required spentSoFar,
    }) async {
      writes.add(takenOn);
      if (fail) throw StateError('disk full');
    });
    final start = DateTime(2026, 11);
    saver.remember(monthStart: start, today: DateTime(2026, 11, 19), range: _range, spentSoFar: 0);
    await Future<void>.delayed(Duration.zero);
    fail = false;
    for (var i = 0; i < 3; i++) {
      saver.remember(
        monthStart: start,
        today: DateTime(2026, 11, 19),
        range: _range,
        spentSoFar: 0,
      );
    }
    saver.remember(monthStart: start, today: DateTime(2026, 11, 20), range: _range, spentSoFar: 0);
    await Future<void>.delayed(Duration.zero);
    expect(writes, [20261119, 20261119, 20261120]);
  });

  test('each saved forecast is set beside what its month really came to', () {
    const calc = PeriodCalculator();
    final october = calc.month(DateTime(2026, 10, 5));
    final september = calc.month(DateTime(2026, 9, 5));
    final rows = [
      txRow(id: 'a', amount: 300000, day: 20261003, at: DateTime(2026, 10, 3)),
      txRow(id: 'b', amount: 200000, day: 20261031, at: DateTime(2026, 10, 31)),
      txRow(id: 'c', amount: 150000, day: 20260910, at: DateTime(2026, 9, 10)),
    ];
    final points = pastSnapshotPoints(
      [
        _snap(20261001, 20261019, 400000),
        _snap(20260901, 20260908, 100000),
        _snap(20260915, 20260920, 1),
      ],
      rows,
      [october, september],
    );
    expect(points.length, 2, reason: 'a month that no longer lines up is left out');
    expect((points[0].dayInPeriod, points[0].point, points[0].actual), (19, 400000, 500000));
    expect((points[1].dayInPeriod, points[1].actual), (8, 150000));
    final errors = snapshotErrors(points, dayInPeriod: 19);
    expect(errors[0], closeTo(0.25, 1e-12));
    expect(errors[1], closeTo(0.5, 1e-12));
  });
}
