/// What the person has taught the suggester, rebuilt in memory from their own entries.
///
/// Two parts, mirroring `PersonalLayer` in ml/category/personal.py:
///
/// 1. Exact-match memory keyed by the payee key. Each past entry for that key weighs
///    [memoryDecay]^r, r = 0 for the newest. The newest entry holds over four fifths of the
///    weight (the older ones add up to under a quarter). With the blend's memory weight of
///    0.9, the latest choice for a known payee gets at least 0.72, above the 0.7 threshold
///    for showing it, so a correction wins on the next entry for that payee.
/// 2. Similar payees. Every other known key with a Jaccard similarity s of at least
///    [minSimilarity] between the two sets of character n-grams adds s squared times its
///    memory to the evidence for each category.
///
/// No Flutter imports.
library;

import '../text_normaliser.dart';
import 'char_ngrams.dart';

const memoryDecay = 0.2;
const minSimilarity = 0.2;

class PersonalLayer {
  /// Builds the layer from [entries], oldest decision first.
  PersonalLayer([Iterable<({String description, String categoryId})> entries = const []]) {
    for (final e in entries) {
      add(e.description, e.categoryId);
    }
  }

  // Key to the categories chosen for it, oldest first. Insertion order is kept, as in Python.
  final _byKey = <String, List<String>>{};
  final _grams = <String, Set<String>>{};
  var _size = 0;

  /// How many entries the layer has learned from.
  int get size => _size;

  void add(String description, String categoryId) {
    final key = payeeKeyOf(description);
    if (key.isEmpty) return;
    _byKey
        .putIfAbsent(key, () {
          _grams[key] = charWbNgrams(key).toSet();
          return <String>[];
        })
        .add(categoryId);
    _size++;
  }

  /// The memory for [key]: share of the recency weight per category, summing to 1, or
  /// empty when the key has never been seen.
  Map<String, double> memory(String key) {
    final cats = _byKey[key];
    if (cats == null || cats.isEmpty) return const {};
    final out = <String, double>{};
    var w = 1.0;
    for (final c in cats.reversed) {
      out[c] = (out[c] ?? 0) + w;
      w *= memoryDecay;
    }
    var total = 0.0;
    for (final v in out.values) {
      total += v;
    }
    return {for (final e in out.entries) e.key: e.value / total};
  }

  /// Evidence per category from keys like [key] (but not [key] itself), and its total.
  ({Map<String, double> evidence, double total}) similar(String key) {
    final grams = charWbNgrams(key).toSet();
    final evidence = <String, double>{};
    if (grams.isEmpty) return (evidence: evidence, total: 0.0);
    for (final MapEntry(key: other, value: otherGrams) in _grams.entries) {
      if (other == key) continue;
      final inter = grams.intersection(otherGrams).length;
      if (inter == 0) continue;
      final s = inter / (grams.length + otherGrams.length - inter);
      if (s < minSimilarity) continue;
      for (final e in memory(other).entries) {
        evidence[e.key] = (evidence[e.key] ?? 0) + s * s * e.value;
      }
    }
    var total = 0.0;
    for (final v in evidence.values) {
      total += v;
    }
    return (evidence: evidence, total: total);
  }
}
