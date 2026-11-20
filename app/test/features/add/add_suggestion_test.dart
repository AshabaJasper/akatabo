import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/add/add_screen.dart';
import 'package:akatabo/features/add/category_suggestion_providers.dart';
import 'package:akatabo/features/add/suggestion_pill.dart';
import 'package:akatabo/smart/category/category_suggester.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

class _RecordingRepository extends TransactionRepository {
  _RecordingRepository() : super(AppDatabase(NativeDatabase.memory()));
  final drafts = <TransactionDraft>[];

  @override
  Future<String> add(TransactionDraft draft) async {
    drafts.add(draft);
    return 'saved-${drafts.length}';
  }
}

final _now = DateTime(2026, 11, 19, 9, 14);
final _model = CategoryModel.fromJsonString(
  File('assets/smart/category_model.json').readAsStringSync(),
);

final _spending = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(
    id: DefaultIds.transport,
    name: 'Transport',
    iconKey: 'bus',
    colourToken: 'cat-amber',
  ),
  categoryRow(id: 'cat.bills', name: 'Bills', iconKey: 'bolt', colourToken: 'cat-blue'),
];

/// Five entries of the person's own, enough to pass the history gate.
PersonalLayer _history() => PersonalLayer([
  (description: 'MTN airtime', categoryId: 'cat.bills'),
  (description: 'Quality Supermarket', categoryId: DefaultIds.food),
  (description: 'posho lunch', categoryId: DefaultIds.food),
  (description: 'Umeme prepaid', categoryId: 'cat.bills'),
  (description: 'taxi fare', categoryId: DefaultIds.transport),
]);

Future<_RecordingRepository> _pumpAdd(
  WidgetTester tester, {
  Map<String, String> settings = const {},
  PersonalLayer? layer,
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _RecordingRepository();
  // Add reads the time when it opens, for its "When" label (and the hour bucket).
  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
          appearanceProvider.overrideWithValue(const AkAppearance()),
          appNowProvider.overrideWithValue(_now),
          spendingCategoriesProvider.overrideWith((ref) => Stream.value(_spending)),
          incomeCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
          enabledAccountsProvider.overrideWith(
            (ref) =>
                Stream.value([accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)]),
          ),
          transactionRepositoryProvider.overrideWithValue(repo),
          categoryModelProvider.overrideWith((ref) => _model),
          personalLayerProvider.overrideWith((ref) => layer ?? _history()),
        ],
        child: MaterialApp(
          theme: buildAkTheme(brightness, const AkAppearance()),
          home: const AddScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
  return repo;
}

Future<void> _type(WidgetTester tester, {String amount = '4000', required String what}) async {
  await tester.enterText(find.byType(TextField).at(0), amount);
  await tester.enterText(find.byType(TextField).at(1), what);
  await tester.pump();
}

bool _tileSelected(WidgetTester tester, String name) =>
    tester.getSemantics(find.bySemanticsLabel(name)).flagsCollection.isSelected == Tristate.isTrue;

void main() {
  testWidgets('words it knows show the pill with how sure it is, and preselect the tile', (
    tester,
  ) async {
    await _pumpAdd(tester);
    expect(find.byType(SuggestionPill), findsNothing, reason: 'nothing typed yet');

    await _type(tester, what: 'boda to work');
    final pill = find.byType(SuggestionPill);
    expect(pill, findsOneWidget);
    final p = tester.widget<SuggestionPill>(pill).probability;
    expect(p, greaterThanOrEqualTo(suggestionThreshold));
    expect(find.text('Suggested: Transport, ${SuggestionPill.percentOf(p)}% sure'), findsOneWidget);
    expect(_tileSelected(tester, 'Transport'), isTrue);
  });

  testWidgets('tapping the pill chooses the category, and it is saved as the suggestion', (
    tester,
  ) async {
    final repo = await _pumpAdd(tester);
    await _type(tester, what: 'boda to work');
    await tester.tap(find.byType(SuggestionPill));
    await tester.pump();
    // The choice stays when the words change and the suggestion goes away.
    await tester.enterText(find.byType(TextField).at(1), 'zz');
    await tester.pump();
    expect(find.byType(SuggestionPill), findsNothing);
    expect(_tileSelected(tester, 'Transport'), isTrue);

    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(repo.drafts.single.categoryId, DefaultIds.transport);
  });

  testWidgets('saving the preselected tile records the suggestion; another tile is a correction', (
    tester,
  ) async {
    final repo = await _pumpAdd(tester);
    await _type(tester, what: 'boda to work');
    await tester.tap(find.bySemanticsLabel('Bills'));
    await tester.pump();
    expect(_tileSelected(tester, 'Bills'), isTrue);
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    final draft = repo.drafts.single;
    expect(draft.categoryId, 'cat.bills');
    expect(draft.suggestedCategoryId, DefaultIds.transport);
    expect(draft.suggestionConfidence, greaterThanOrEqualTo(suggestionThreshold));
  });

  testWidgets('the grid stays still as the pill comes and goes', (tester) async {
    await _pumpAdd(tester);
    final before = tester.getTopLeft(find.bySemanticsLabel('Transport'));
    await _type(tester, what: 'boda to work');
    expect(find.byType(SuggestionPill), findsOneWidget);
    expect(tester.getTopLeft(find.bySemanticsLabel('Transport')), before);
  });

  testWidgets('no pill when Suggest a category is off', (tester) async {
    await _pumpAdd(tester, settings: {SettingKeys.suggestCategory.name: 'false'});
    await _type(tester, what: 'boda to work');
    expect(find.byType(SuggestionPill), findsNothing);
    expect(_tileSelected(tester, 'Transport'), isFalse);
  });

  testWidgets('no pill without enough history of the person\'s own', (tester) async {
    await _pumpAdd(
      tester,
      layer: PersonalLayer([(description: 'taxi', categoryId: 'cat.transport')]),
    );
    await _type(tester, what: 'boda to work');
    expect(find.byType(SuggestionPill), findsNothing);
  });

  testWidgets('suggestion pill golden', (tester) async {
    await _pumpAdd(tester);
    await _type(tester, amount: '45000', what: 'Groceries, Nakasero market');
    await tester.pumpAndSettle();
    expect(find.byType(SuggestionPill), findsOneWidget);
    await expectLater(
      find.byType(AddScreen),
      matchesGoldenFile('goldens/add_suggestion_light.png'),
    );
  });

  test('the layer learns only from categorised entries since the last reset, newest last', () {
    Transaction row(String what, String? cat, int created, int updated, {Direction? d}) =>
        txRow(description: what, categoryId: cat, direction: d ?? Direction.moneyOut).copyWith(
          createdAt: DateTime.fromMillisecondsSinceEpoch(created),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(updated),
        );
    final layer = personalLayerFrom([
      row('boda', 'cat.family', 2000, 5000), // changed last, so it wins
      row('boda', 'cat.transport', 3000, 3000),
      row('boda', 'cat.food', 500, 9000), // before the reset
      row('', 'cat.food', 2000, 2000), // no words
      row('to savings', null, 2000, 2000, d: Direction.transfer),
    ], learnedSinceMs: 1000);
    expect(layer.size, 2);
    final mem = layer.memory('boda');
    expect(mem.entries.reduce((a, b) => b.value > a.value ? b : a).key, 'cat.family');
  });
}
