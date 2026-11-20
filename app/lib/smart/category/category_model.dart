/// The category model exported by ml/category/export.py (trained on SYNTHETIC entries):
/// TF-IDF over character n-grams of the payee key, plus one amount bucket and one hour
/// bucket, into a multinomial logistic regression.
///
/// Mirrors `ExportedModel` in ml/category/export.py step for step, in the same order of
/// additions, so the parity test can hold the two to 1e-6. No Flutter imports.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../text_normaliser.dart';
import 'char_ngrams.dart';

const categoryModelFormat = 'akatabo.category.v1';

class CategoryModel {
  CategoryModel._({
    required this.classes,
    required Map<String, int> index,
    required Float64List idf,
    required List<Float64List> coef,
    required Float64List intercept,
    required this.ngramMin,
    required this.ngramMax,
    required this.amountEdges,
    required this.hourEdges,
  }) : _index = index, // ignore: prefer_initializing_formals
       _idf = idf, // ignore: prefer_initializing_formals
       _coef = coef, // ignore: prefer_initializing_formals
       _intercept = intercept; // ignore: prefer_initializing_formals

  /// Reads the JSON the export writes. Throws [FormatException] when it is not that file
  /// or its parts do not fit together.
  factory CategoryModel.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Not a category model');
    if (decoded['format'] != categoryModelFormat) {
      throw FormatException('Unknown category model format: ${decoded['format']}');
    }
    List<T> list<T>(String key) {
      final v = decoded[key];
      if (v is! List) throw FormatException('Missing $key');
      return v.cast<T>();
    }

    Float64List floats(List<dynamic> v) =>
        Float64List.fromList([for (final x in v) (x as num).toDouble()]);

    final classes = List<String>.unmodifiable(list<String>('classes'));
    final vocabulary = list<String>('vocabulary');
    final idf = floats(list<dynamic>('idf'));
    final amountEdges = List<int>.unmodifiable(list<int>('amountEdges'));
    final hourEdges = List<int>.unmodifiable(list<int>('hourEdges'));
    final ngram = list<int>('ngram');
    final coef = [for (final row in list<List<dynamic>>('coef')) floats(row)];
    final intercept = floats(list<dynamic>('intercept'));
    final width = vocabulary.length + amountEdges.length + 1 + hourEdges.length + 1;
    if (ngram.length != 2 ||
        idf.length != vocabulary.length ||
        coef.length != classes.length ||
        intercept.length != classes.length ||
        coef.any((r) => r.length != width)) {
      throw const FormatException('Category model parts do not fit together');
    }
    return CategoryModel._(
      classes: classes,
      index: {for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i},
      idf: idf,
      coef: coef,
      intercept: intercept,
      ngramMin: ngram[0],
      ngramMax: ngram[1],
      amountEdges: amountEdges,
      hourEdges: hourEdges,
    );
  }

  /// Category ids the model knows, in the order of its coefficients.
  final List<String> classes;
  final int ngramMin;
  final int ngramMax;

  /// Shillings and local hours; a value falls in the bucket after every edge at or below it.
  final List<int> amountEdges;
  final List<int> hourEdges;

  final Map<String, int> _index;
  final Float64List _idf;
  final List<Float64List> _coef;
  final Float64List _intercept;

  int get vocabularySize => _index.length;

  /// How many edges are at or below [value] (Python's bisect_right).
  static int bucketOf(List<int> edges, int value) {
    var i = 0;
    while (i < edges.length && edges[i] <= value) {
      i++;
    }
    return i;
  }

  /// The model's probability for each of [classes], summing to 1.
  Map<String, double> probabilities(String description, {required int amount, required int hour}) {
    // Term counts in first-seen order, as Python's Counter keeps them.
    final counts = <int, int>{};
    for (final g in charWbNgrams(payeeKeyOf(description), min: ngramMin, max: ngramMax)) {
      final j = _index[g];
      if (j != null) counts[j] = (counts[j] ?? 0) + 1;
    }
    final x = <int, double>{for (final e in counts.entries) e.key: e.value * _idf[e.key]};
    var sumSq = 0.0;
    for (final v in x.values) {
      sumSq += v * v;
    }
    final norm = math.sqrt(sumSq);
    if (norm > 0) {
      for (final j in x.keys.toList()) {
        x[j] = x[j]! / norm;
      }
    }
    final columns = x.keys.toList()..sort();
    final a = vocabularySize + bucketOf(amountEdges, amount);
    final h = vocabularySize + amountEdges.length + 1 + bucketOf(hourEdges, hour);
    final logits = Float64List(classes.length);
    for (var k = 0; k < classes.length; k++) {
      final row = _coef[k];
      var z = _intercept[k];
      for (final j in columns) {
        z += row[j] * x[j]!;
      }
      z += row[a] + row[h];
      logits[k] = z;
    }
    final top = logits.reduce(math.max);
    final exps = [for (final z in logits) math.exp(z - top)];
    var total = 0.0;
    for (final e in exps) {
      total += e;
    }
    return {for (var k = 0; k < classes.length; k++) classes[k]: exps[k] / total};
  }
}
