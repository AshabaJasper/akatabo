import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../smart/category/category_suggester.dart';

/// Where the exported category model ships (written by ml/category/export.py).
const categoryModelAsset = 'assets/smart/category_model.json';

/// The category model, read once from the app's assets. An error leaves Add without
/// suggestions; the person can still pick a category.
final categoryModelProvider = FutureProvider<CategoryModel>(
  (ref) async => CategoryModel.fromJsonString(await rootBundle.loadString(categoryModelAsset)),
);

/// What the person has taught the suggester: their categorised entries made since "Forget
/// everything it has learned". Read once each time Add opens (Add closes on save, so the
/// next Add sees the new entry); it lives only while Add is open.
final personalLayerProvider = FutureProvider.autoDispose<PersonalLayer>((ref) async {
  final stored = ref.watch(storedSettingsProvider).value;
  final resetAt = SettingKeys.learningResetAt.decode(stored?[SettingKeys.learningResetAt.name]);
  final rows = await ref.watch(transactionRepositoryProvider).listAll();
  return personalLayerFrom(rows, learnedSinceMs: resetAt);
});

/// The layer from [rows] (any order): entries with a category and a description, made at
/// or after [learnedSinceMs], ordered by when the category was last chosen so the newest
/// choice for a payee counts most.
PersonalLayer personalLayerFrom(Iterable<Transaction> rows, {required int learnedSinceMs}) {
  final kept = [
    for (final t in rows)
      if (t.categoryId != null &&
          t.direction != Direction.transfer &&
          t.description.trim().isNotEmpty &&
          t.createdAt.millisecondsSinceEpoch >= learnedSinceMs)
        t,
  ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  return PersonalLayer([
    for (final t in kept) (description: t.description, categoryId: t.categoryId!),
  ]);
}

/// The suggester when suggestions are switched on and both parts are ready; null otherwise,
/// so Add simply shows no pill.
final categorySuggesterProvider = Provider.autoDispose<CategorySuggester?>((ref) {
  final stored = ref.watch(storedSettingsProvider).value;
  if (stored == null) return null;
  if (!SettingKeys.suggestCategory.decode(stored[SettingKeys.suggestCategory.name])) return null;
  final model = ref.watch(categoryModelProvider).value;
  final personal = ref.watch(personalLayerProvider).value;
  if (model == null || personal == null) return null;
  return CategorySuggester(model, personal);
});
