import 'dart:convert';
import 'dart:io';

import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:flutter_test/flutter_test.dart';

ForecastRange _range({
  List<int> daily = const [0, 12000, 8000, 30000, 5000, 0, 15000, 22000, 9000, 11000],
  int spentToday = 0,
  int daysLeft = 12,
  List<RegularBand> regular = const [RegularBand(low: 590000, typical: 600000, high: 610000)],
  List<double> errors = const [],
}) => forecastRange(
  spentSoFar: 400000,
  everydayDaily: daily,
  spentToday: spentToday,
  daysLeft: daysLeft,
  regular: regular,
  dayOfMonth: 18,
  snapshotErrors: errors,
);

void main() {
  group('xorshift', () {
    test('the first outputs for day 1 are fixed', () {
      // Written out, so a changed seed or shift fails here as well as in the parity test.
      final rng = Xorshift32.forDay(1);
      expect(
        [for (var i = 0; i < 5; i++) rng.next()],
        [1359504952, 3827716927, 3866437631, 332804602, 1758100174],
      );
      expect(forecastSeed, 0x9E3779B9);
    });

    test('stays within 32 bits and never reaches 0', () {
      final rng = Xorshift32.forDay(31);
      for (var i = 0; i < 10000; i++) {
        final x = rng.next();
        expect(x > 0 && x <= 0xFFFFFFFF, isTrue);
      }
    });

    test('the same day gives the same stream, another day another', () {
      final a = Xorshift32.forDay(5);
      final b = Xorshift32.forDay(5);
      final c = Xorshift32.forDay(6);
      expect(a.next(), b.next());
      expect(Xorshift32.forDay(5).next(), isNot(c.next()));
    });
  });

  group('percentile', () {
    test('interpolates linearly between ranks', () {
      const s = [10, 20, 30, 40, 50];
      expect(percentile(s, 0), 10);
      expect(percentile(s, 1), 50);
      expect(percentile(s, 0.5), 30);
      expect(percentile(s, 0.1), closeTo(14, 1e-12));
      expect(percentile(s, 0.9), closeTo(46, 1e-12));
      expect(percentile(const [7], 0.9), 7);
      expect(percentile(const [], 0.5), 0);
    });

    test('roundHalfUp rounds halves up', () {
      expect(roundHalfUp(2.5), 3);
      expect(roundHalfUp(2.4999), 2);
      expect(roundHalfUp(-2.5), -2);
    });
  });

  group('range', () {
    test('the point is the Phase 3 rule and the range contains it', () {
      final r = _range();
      const mean = 112000 / 10;
      expect(r.point, 400000 + (mean + mean * 12).round() + 600000);
      expect(r.low, lessThanOrEqualTo(r.point));
      expect(r.high, greaterThanOrEqualTo(r.point));
      expect(r.low, lessThan(r.high));
      expect(r.low, greaterThanOrEqualTo(400000));
    });

    test('is the same every time for the same inputs', () {
      final a = _range();
      final b = _range();
      expect((a.low, a.point, a.high), (b.low, b.point, b.high));
    });

    test('with no history it is the regular bands only', () {
      final r = _range(
        daily: const [],
        regular: const [RegularBand(low: 90, typical: 100, high: 120)],
      );
      expect((r.low, r.point, r.high), (400090, 400100, 400120));
    });
  });

  group('snapshot adjustment', () {
    test('months with no snapshot leave the range alone', () {
      expect(_range().monthsUsed, 0);
    });

    test('past errors beyond the range widen it; small ones never narrow it', () {
      final plain = _range();
      final wide = _range(errors: const [0.5, 0.4, -0.5]);
      expect(wide.monthsUsed, 3);
      expect(wide.low, lessThan(plain.low));
      expect(wide.high, greaterThan(plain.high));
      final tiny = _range(errors: const [0, 0, 0, 0]);
      expect((tiny.low, tiny.high), (plain.low, plain.high));
    });

    test('one month counts for less than six', () {
      expect(_range(errors: const [0.5]).high, lessThan(_range(errors: List.filled(6, 0.5)).high));
    });

    test('only the twelve newest months count', () {
      final r = _range(errors: [...List.filled(12, 0.0), 5.0]);
      expect(r.monthsUsed, 12);
      expect(r.high, _range().high);
    });

    test('each month uses its snapshot nearest the same day, newest month first', () {
      final errors = snapshotErrors(const [
        SnapshotPoint(periodStart: 20260901, dayInPeriod: 10, point: 1000000, actual: 1200000),
        SnapshotPoint(periodStart: 20260901, dayInPeriod: 14, point: 1100000, actual: 1200000),
        SnapshotPoint(periodStart: 20261001, dayInPeriod: 3, point: 900000, actual: 990000),
        SnapshotPoint(periodStart: 20261001, dayInPeriod: 25, point: 1000000, actual: 990000),
        SnapshotPoint(periodStart: 20260801, dayInPeriod: 12, point: 0, actual: 500000),
      ], dayInPeriod: 12);
      expect(errors.length, 2);
      expect(errors[0], closeTo(0.1, 1e-12));
      expect(errors[1], closeTo(0.2, 1e-12));
    });
  });

  test('the constants match assets/smart/forecast_params.json', () {
    final p = jsonDecode(
      File('assets/smart/forecast_params.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final prng = p['prng'] as Map<String, dynamic>;
    final adj = p['snapshotAdjustment'] as Map<String, dynamic>;
    expect(prng['seed'], forecastSeed);
    expect(prng['shifts'], [13, 17, 5]);
    expect(p['samples'], forecastSamples);
    expect(p['percentileLow'], forecastPercentileLow);
    expect(p['percentileHigh'], forecastPercentileHigh);
    expect(adj['shrinkMonths'], forecastShrinkMonths);
    expect(adj['maxMonths'], forecastMaxMonths);
  });
}
