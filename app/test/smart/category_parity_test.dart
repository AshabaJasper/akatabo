import 'dart:convert';
import 'dart:io';

import 'package:akatabo/smart/category/category_suggester.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone must give the probabilities Python gives (ml/category/export.py writes the
/// fixtures from the shipped, rounded model). All data is SYNTHETIC.
void main() {
  final model = CategoryModel.fromJsonString(
    File('assets/smart/category_model.json').readAsStringSync(),
  );
  final fixtures = jsonDecode(
    File('test/smart/fixtures/category_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  void expectSame(Map<String, double> mine, Map<String, dynamic> theirs, String top) {
    expect(mine.keys.toSet(), theirs.keys.toSet());
    for (final e in theirs.entries) {
      expect(mine[e.key], closeTo((e.value as num).toDouble(), 1e-6), reason: e.key);
    }
    final myTop = mine.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    expect(myTop, top);
  }

  test('the model gives Python\'s probabilities for every fixture', () {
    final cases = (fixtures['model'] as List).cast<Map<String, dynamic>>();
    expect(cases.length, greaterThanOrEqualTo(40));
    var worst = 0.0;
    for (final c in cases) {
      final mine = model.probabilities(
        c['description'] as String,
        amount: c['amount'] as int,
        hour: c['hour'] as int,
      );
      final theirs = c['probs'] as Map<String, dynamic>;
      for (final e in theirs.entries) {
        final d = (mine[e.key]! - (e.value as num)).abs();
        if (d > worst) worst = d;
      }
      expectSame(mine, theirs, c['top'] as String);
    }
    // Printed so the report can quote it.
    // ignore: avoid_print
    print('category parity: max difference $worst over ${cases.length} cases');
  });

  test('the blend with a personal layer gives Python\'s probabilities', () {
    final blend = fixtures['blend'] as Map<String, dynamic>;
    final layer = PersonalLayer([
      for (final h in (blend['history'] as List).cast<Map<String, dynamic>>())
        (description: h['description'] as String, categoryId: h['categoryId'] as String),
    ]);
    final suggester = CategorySuggester(model, layer);
    for (final c in (blend['cases'] as List).cast<Map<String, dynamic>>()) {
      final mine = suggester.blended(
        c['description'] as String,
        amount: c['amount'] as int,
        hour: c['hour'] as int,
      );
      expectSame(mine, c['probs'] as Map<String, dynamic>, c['top'] as String);
    }
  });

  test('the shipped model is the synthetic one, small, with the default categories', () {
    expect(model.classes, contains('cat.food'));
    expect(model.vocabularySize, lessThanOrEqualTo(3000));
    expect(File('assets/smart/category_model.json').lengthSync(), lessThan(400 * 1024));
  });

  test('a file that is not a category model is refused', () {
    expect(() => CategoryModel.fromJsonString('{"format":"other"}'), throwsFormatException);
    expect(() => CategoryModel.fromJsonString('[]'), throwsFormatException);
  });
}
