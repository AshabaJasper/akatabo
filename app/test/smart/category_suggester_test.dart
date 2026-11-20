import 'dart:io';

import 'package:akatabo/smart/category/category_suggester.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a correction changes the next suggestion. The model is the shipped one (trained on
/// SYNTHETIC entries).
void main() {
  final model = CategoryModel.fromJsonString(
    File('assets/smart/category_model.json').readAsStringSync(),
  );
  const offered = {
    'cat.food',
    'cat.transport',
    'cat.bills',
    'cat.school',
    'cat.family',
    'cat.health',
    'cat.other',
    'cat.custom.work',
  };

  /// Five unrelated entries, so the history gate is passed.
  final background = [
    (description: 'MTN airtime', categoryId: 'cat.bills'),
    (description: 'school fees', categoryId: 'cat.school'),
    (description: 'pharmacy', categoryId: 'cat.health'),
    (description: 'send to mum', categoryId: 'cat.family'),
    (description: 'Quality Supermarket', categoryId: 'cat.food'),
  ];

  CategorySuggestion? suggest(PersonalLayer layer, String text, {int amount = 4000}) =>
      CategorySuggester(model, layer).suggest(text, amount: amount, hour: 8, offered: offered);

  test('after a correction, the same payee is suggested in the corrected category', () {
    final layer = PersonalLayer(background);
    final before = suggest(layer, 'Boda to work');
    expect(before?.categoryId, 'cat.transport');

    // The person corrects it to a category of their own, which the model has never seen.
    layer.add('Boda to work', 'cat.custom.work');
    final after = suggest(layer, 'boda  to WORK');
    expect(after?.categoryId, 'cat.custom.work');
    expect(after!.probability, greaterThan(0.85));
  });

  test('the newest choice wins even after many older ones', () {
    final layer = PersonalLayer(background);
    for (var i = 0; i < 20; i++) {
      layer.add('Nakasero market', 'cat.food');
    }
    layer.add('Nakasero market', 'cat.family');
    expect(suggest(layer, 'Nakasero market', amount: 15000)?.categoryId, 'cat.family');
  });

  test('one similar but different payee moves the answer only partly', () {
    final layer = PersonalLayer(background)..add('boda to office', 'cat.custom.work');
    final suggester = CategorySuggester(model, layer);
    final p = suggester.blended('boda to work', amount: 4000, hour: 8);
    final plain = CategorySuggester(
      model,
      PersonalLayer(background),
    ).blended('boda to work', amount: 4000, hour: 8);
    expect(p['cat.custom.work'], greaterThan(0.05));
    expect(p['cat.custom.work'], lessThan(0.5));
    expect(p['cat.transport'], lessThan(plain['cat.transport']!));
    expect(suggest(layer, 'boda to work')?.categoryId, 'cat.transport');
  });

  test('no suggestion without enough history, words, or confidence', () {
    final few = PersonalLayer(background.take(4));
    expect(suggest(few, 'Boda to work'), isNull);
    final layer = PersonalLayer(background);
    expect(suggest(layer, 'ab'), isNull);
    expect(suggest(layer, '!!'), isNull);
    // A word the model has no idea about stays under the threshold.
    expect(suggest(layer, 'qqqq zzzz'), isNull);
  });

  test('only categories on offer are suggested, and the share is among them', () {
    final layer = PersonalLayer(background);
    final s = CategorySuggester(
      model,
      layer,
    ).suggest('boda to work', amount: 4000, hour: 8, offered: {'cat.food', 'cat.transport'});
    expect(s?.categoryId, 'cat.transport');
    final none = CategorySuggester(
      model,
      layer,
    ).suggest('boda to work', amount: 4000, hour: 8, offered: {'cat.salary'});
    expect(none, isNull);
  });
}
