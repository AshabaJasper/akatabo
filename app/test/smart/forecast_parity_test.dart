import 'dart:convert';
import 'dart:io';

import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart range must give exactly what the Python reference gave for the same SYNTHETIC
/// inputs (ml/forecast/export.py writes the fixture). Integers must match exactly; the
/// unrounded percentiles and errors within 1e-9.
void main() {
  final vectors = jsonDecode(
    File('test/smart/fixtures/forecast_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the fixture is synthetic and has about twenty cases', () {
    expect(vectors['synthetic'], isTrue);
    expect((vectors['cases'] as List).length, 20);
  });

  test('the xorshift gives the Python stream', () {
    final rng = Xorshift32.forDay(1);
    expect([for (var i = 0; i < 5; i++) rng.next()], vectors['xorshiftDay1First5']);
  });

  final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();
  for (final (i, c) in cases.indexed) {
    test('range case $i matches Python', () {
      final input = c['input'] as Map<String, dynamic>;
      final r = forecastRange(
        spentSoFar: input['spentSoFar'] as int,
        everydayDaily: (input['daily'] as List).cast<int>(),
        spentToday: input['spentToday'] as int,
        daysLeft: input['daysLeft'] as int,
        regular: [
          for (final b in (input['regular'] as List).cast<Map<String, dynamic>>())
            RegularBand(low: b['low'] as int, typical: b['typical'] as int, high: b['high'] as int),
        ],
        dayOfMonth: input['dayOfMonth'] as int,
        snapshotErrors: [for (final e in input['snapshotErrors'] as List) (e as num).toDouble()],
      );
      expect(r.low, c['low']);
      expect(r.point, c['point']);
      expect(r.high, c['high']);
      expect(r.monthsUsed, c['monthsUsed']);
      expect(r.everydayLow, closeTo((c['everydayLow'] as num).toDouble(), 1e-9));
      expect(r.everydayHigh, closeTo((c['everydayHigh'] as num).toDouble(), 1e-9));
    });
  }

  final snaps = (vectors['snapshotCases'] as List).cast<Map<String, dynamic>>();
  for (final (i, s) in snaps.indexed) {
    test('snapshot errors case $i match Python', () {
      final errors = snapshotErrors([
        for (final p in (s['snapshots'] as List).cast<Map<String, dynamic>>())
          SnapshotPoint(
            periodStart: p['periodStart'] as int,
            dayInPeriod: p['dayInPeriod'] as int,
            point: p['point'] as int,
            actual: p['actual'] as int,
          ),
      ], dayInPeriod: s['dayInPeriod'] as int);
      final expected = [for (final e in s['errors'] as List) (e as num).toDouble()];
      expect(errors.length, expected.length);
      for (var k = 0; k < errors.length; k++) {
        expect(errors[k], closeTo(expected[k], 1e-9));
      }
    });
  }
}
