/// Blends the model with the person's own layer and decides whether to suggest at all.
///
///   P = m * memory + (1 - m) * (w * similar + (1 - w) * model)
///
/// m is [memoryWeight] when the payee key has been seen, else 0; w = E / (E + 1) where E is
/// the similar-payee evidence, so one similar payee moves the answer only partly. A category
/// the model does not know (one the person made) is reachable through the first two parts.
/// "87% sure" is this P, restricted to the categories on offer, computed on the phone.
///
/// Mirrors `blend` in ml/category/personal.py. Thresholds are chosen in
/// ml/category/RESULTS.md. No Flutter imports.
library;

import '../text_normaliser.dart';
import 'category_model.dart';
import 'personal_layer.dart';

export 'category_model.dart';
export 'personal_layer.dart';

const memoryWeight = 0.9;
const tokenPseudoCount = 1.0;

/// No suggestion until the person has this many categorised entries of their own (since
/// "Forget everything it has learned").
const minHistoryForSuggestions = 5;

/// No suggestion for fewer letters and digits than this in the description.
const minDescriptionLength = 3;

/// The pill shows only at or above this blended probability.
const suggestionThreshold = 0.7;

class CategorySuggestion {
  const CategorySuggestion(this.categoryId, this.probability);
  final String categoryId;

  /// 0 to 1, among the categories on offer.
  final double probability;

  @override
  String toString() => 'CategorySuggestion($categoryId, $probability)';
}

class CategorySuggester {
  const CategorySuggester(this.model, this.personal);

  final CategoryModel model;
  final PersonalLayer personal;

  /// The full blended distribution over every category the model or the person knows.
  Map<String, double> blended(String description, {required int amount, required int hour}) {
    final modelProbs = model.probabilities(description, amount: amount, hour: hour);
    final key = payeeKeyOf(description);
    final mem = key.isEmpty ? const <String, double>{} : personal.memory(key);
    final sim = key.isEmpty
        ? (evidence: const <String, double>{}, total: 0.0)
        : personal.similar(key);
    final m = mem.isEmpty ? 0.0 : memoryWeight;
    final w = sim.total / (sim.total + tokenPseudoCount);
    final cats = {...modelProbs.keys, ...mem.keys, ...sim.evidence.keys};
    return {
      for (final c in cats)
        c:
            m * (mem[c] ?? 0) +
            (1 - m) *
                (w * (sim.total > 0 ? (sim.evidence[c] ?? 0) / sim.total : 0) +
                    (1 - w) * (modelProbs[c] ?? 0)),
    };
  }

  /// The category to suggest among [offered], or null when there is too little to go on
  /// or the best guess is below [suggestionThreshold].
  CategorySuggestion? suggest(
    String description, {
    required int amount,
    required int hour,
    required Set<String> offered,
  }) {
    if (personal.size < minHistoryForSuggestions) return null;
    if (payeeKeyOf(description).replaceAll(' ', '').length < minDescriptionLength) return null;
    final p = blended(description, amount: amount, hour: hour);
    var total = 0.0;
    String? best;
    var bestP = 0.0;
    for (final e in p.entries) {
      if (!offered.contains(e.key)) continue;
      total += e.value;
      if (e.value > bestP) {
        best = e.key;
        bestP = e.value;
      }
    }
    if (best == null || total <= 0) return null;
    final share = bestP / total;
    return share >= suggestionThreshold ? CategorySuggestion(best, share) : null;
  }
}
