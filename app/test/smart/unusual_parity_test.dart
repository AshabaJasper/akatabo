import 'dart:convert';
import 'dart:io';

import 'package:akatabo/smart/regular/stats.dart';
import 'package:akatabo/smart/unusual/unusual_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Python reference (ml/unusual/score.py) wrote these vectors from SYNTHETIC inputs.
/// Dart must give the same scores within 1e-9 and exactly the same flags and reasons.
void main() {
  final fixture = jsonDecode(
    File('test/smart/fixtures/unusual_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final params = UnusualParams.fromJson(fixture['params']! as Map<String, Object?>);
  var maxDiff = 0.0;

  void expectSame(UnusualResult r, Map<String, Object?> want, String name) {
    void close(double got, Object? expected, String what) {
      final e = (expected! as num).toDouble();
      final d = (got - e).abs();
      if (d > maxDiff) maxDiff = d;
      expect(d, lessThanOrEqualTo(1e-9), reason: '$name: $what $got vs $e');
    }

    close(r.score, want['score'], 'score');
    close(r.signals.amountZ, want['amountZ'], 'amountZ');
    close(r.signals.usualAmount, want['usualAmount'], 'usualAmount');
    close(r.signals.hourShare, want['hourShare'], 'hourShare');
    expect(r.flagged, want['flagged'], reason: '$name: flagged');
    expect([for (final x in r.reasons) x.name], want['reasons'], reason: '$name: reasons');
    expect(r.signals.gatePassed, want['gatePassed'], reason: '$name: gate');
    expect(r.signals.basis.name, want['basis'], reason: '$name: basis');
    expect(r.signals.newPayee, want['newPayee'], reason: '$name: new payee');
  }

  test('the synthetic sequence scores the same as Python', () {
    final seq = fixture['sequence']! as Map<String, Object?>;
    final entries = [
      for (final e in seq['entries']! as List) UnusualEntry.fromJson(e as Map<String, Object?>),
    ];
    final targets = seq['targets']! as List;
    expect(targets, isNotEmpty);
    for (final t in targets.cast<Map<String, Object?>>()) {
      final i = t['index']! as int;
      final level = UnusualLevel.values.byName(t['setting']! as String);
      final r = scoreUnusual(entries[i], entries.sublist(0, i), params, level: level);
      expectSame(r, t['expected']! as Map<String, Object?>, 'row $i');
    }
  });

  test('hand-made edge cases score the same as Python', () {
    final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
    expect(cases.length, greaterThanOrEqualTo(10));
    for (final c in cases) {
      final r = scoreUnusual(
        UnusualEntry.fromJson(c['entry']! as Map<String, Object?>),
        [for (final h in c['history']! as List) UnusualEntry.fromJson(h as Map<String, Object?>)],
        params,
        level: UnusualLevel.values.byName(c['setting']! as String),
      );
      expectSame(r, c['expected']! as Map<String, Object?>, c['name']! as String);
    }
  });

  test('the bundled artefact holds the same constants as the vectors', () {
    final asset = jsonDecode(
      File('assets/smart/unusual_params.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final a = UnusualParams.fromJson(asset);
    expect(a.thresholds, params.thresholds);
    expect(a.hourWeight, params.hourWeight);
    expect(a.payeeWeight, params.payeeWeight);
    expect(a.madFloor, params.madFloor);
    expect(a.minCategoryHistory, params.minCategoryHistory);
    expect(
      a.thresholds[UnusualLevel.rarely]! >= a.thresholds[UnusualLevel.balanced]! &&
          a.thresholds[UnusualLevel.balanced]! >= a.thresholds[UnusualLevel.often]!,
      isTrue,
    );
  });

  test('median and the edit distance agree with the reference examples', () {
    expect(medianOf([3, 1, 2]), 2.0);
    expect(medianOf([4, 1, 3, 2]), 2.5);
    expect(osaDistance('shop', 'sohp'), 1);
    expect(osaDistance('kitten', 'sitting'), 3);
    expect(osaDistance('abc', ''), 3);
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('unusual parity: max abs difference $maxDiff');
  });
}
