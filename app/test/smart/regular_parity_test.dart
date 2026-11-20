import 'dart:convert';
import 'dart:io';

import 'package:akatabo/smart/regular/regular_detector.dart';
import 'package:akatabo/smart/regular/stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Python reference (ml/regular/detect.py) wrote these vectors from SYNTHETIC inputs.
/// Dart must find the same series with the same dates and amounts, and the same interval
/// and gap spread within 1e-9.
void main() {
  final fixture = jsonDecode(
    File('test/smart/fixtures/regular_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final params = RegularParams.fromJson(fixture['params']! as Map<String, Object?>);
  final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
  var maxDiff = 0.0;

  test('every vector gives the same series as Python', () {
    expect(cases.length, greaterThanOrEqualTo(30));
    for (final c in cases) {
      final name = c['name']! as String;
      final got = detectRegular(
        [for (final p in c['payments']! as List) PaidEntry.fromJson(p as Map<String, Object?>)],
        c['today']! as int,
        params,
      );
      final want = (c['expected']! as List).cast<Map<String, Object?>>();
      expect(got.length, want.length, reason: '$name: series count');
      for (var i = 0; i < want.length; i++) {
        final g = got[i];
        final w = want[i];
        expect(g.payeeKey, w['payeeKey'], reason: name);
        expect(g.categoryId, w['categoryId'], reason: name);
        expect(g.occurrences, w['occurrences'], reason: name);
        expect(g.intervalDays, w['intervalDays'], reason: name);
        expect(g.typicalAmount, w['typicalAmount'], reason: name);
        expect(g.amountLow, w['amountLow'], reason: name);
        expect(g.amountHigh, w['amountHigh'], reason: name);
        expect(g.lastDay, w['lastDay'], reason: name);
        expect(g.nextDay, w['nextDay'], reason: '$name: next day');
        expect(g.nextDueFromToday, w['nextDueFromToday'], reason: '$name: next due');
        for (final (got, key) in [(g.interval, 'interval'), (g.gapCv, 'gapCv')]) {
          final d = (got - (w[key]! as num).toDouble()).abs();
          if (d > maxDiff) maxDiff = d;
          expect(d, lessThanOrEqualTo(1e-9), reason: '$name: $key');
        }
      }
    }
  });

  test('the bundled artefact holds the same constants as the vectors', () {
    final asset = RegularParams.fromJson(
      jsonDecode(File('assets/smart/regular_params.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(asset.cvMax, params.cvMax);
    expect(asset.minIntervalDays, params.minIntervalDays);
    expect(asset.amountShareMin, params.amountShareMin);
    expect(asset.maxMissedShare, params.maxMissedShare);
  });

  test('rounding is half up, as in Python', () {
    expect(roundHalfUp(2.5), 3);
    expect(roundHalfUp(30.4999), 30);
    expect(plainSum([0.1, 0.2, 0.3]), (0.1 + 0.2) + 0.3);
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('regular parity: max abs difference $maxDiff');
  });
}
