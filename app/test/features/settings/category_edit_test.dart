import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/settings/categories_settings_screen.dart';
import 'package:akatabo/features/settings/category_edit_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../flutter_test_config.dart';

/// Pumps [screen] over a real in-memory database. The category list comes from the database
/// once, read on the real clock, so the screen sees exactly what is stored.
Future<AppDatabase> _pump(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 3000),
  Future<void> Function(AppDatabase db)? prepare,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final cats = await tester.runAsync(() async {
    await prepare?.call(db);
    return CategoryRepository(db).watchAll().first;
  });
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        appNowProvider.overrideWithValue(testNow),
        allCategoriesProvider.overrideWith((ref) => Stream.value(cats!)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return db;
}

/// Lets a database write finish on the real clock, then redraws the frames it caused.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Category> _row(WidgetTester tester, AppDatabase db, String id) async => (await tester
    .runAsync(() => (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle()))!;

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label && w.child is TextField,
);

Finder _editable(String label) =>
    find.descendant(of: _field(label), matching: find.byType(TextField));

Future<void> _addBudget(AppDatabase db) =>
    CategoryRepository(db)
        .setBudget(DefaultIds.transport, monthlyBudget: 200000, carriesOver: true, warnAt: 90);

void main() {
  group('Edit a category', () {
    testWidgets('it loads the category and saves a new name, colour, icon and budget', (
      tester,
    ) async {
      final db = await _pump(
        tester,
        const CategoryEditScreen(categoryId: DefaultIds.transport),
        prepare: _addBudget,
      );
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('200,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to Categories'), findsOneWidget);

      await tester.enterText(_editable('Name'), 'Boda and taxi');
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.tap(find.bySemanticsLabel('Fuel'));
      await tester.enterText(_editable('UGX'), '250000');
      await tester.pump();
      expect(find.text('250,000'), findsOneWidget);
      await tester.tap(find.text('Save category'));
      await _settle(tester);

      final r = await _row(tester, db, DefaultIds.transport);
      expect((r.name, r.colourToken, r.iconKey), ('Boda and taxi', 'cat-red', 'fuel'));
      // The budget keeps the options chosen on Set a budget.
      expect((r.monthlyBudget, r.budgetCarriesOver, r.budgetWarnAt), (250000, true, 90));
    });

    testWidgets('colours and icons are named and marked when chosen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const CategoryEditScreen(categoryId: DefaultIds.transport));
      expect(tester.getSemantics(find.bySemanticsLabel('Amber')), isSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Green')), isSemantics(isSelected: false));
      expect(tester.getSemantics(find.bySemanticsLabel('Bus')), isSemantics(isSelected: true));

      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.pump();
      expect(tester.getSemantics(find.bySemanticsLabel('Teal')), isSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Amber')), isSemantics(isSelected: false));
      // Every swatch and icon tile is a 44px target.
      expect(tester.getSize(find.bySemanticsLabel('Teal')), const Size(44, 44));
      expect(tester.getSize(find.bySemanticsLabel('Airtime and data')), const Size(44, 44));
      handle.dispose();
    });

    testWidgets('it refuses an empty name and a name another category has', (tester) async {
      final db = await _pump(tester, const CategoryEditScreen(categoryId: DefaultIds.food));

      await tester.enterText(_editable('Name'), '   ');
      await tester.tap(find.text('Save category'));
      await tester.pump();
      expect(find.text('Give the category a name.'), findsOneWidget);

      await tester.enterText(_editable('Name'), 'transport');
      await tester.tap(find.text('Save category'));
      await _settle(tester);
      expect(find.text('Another category already has this name.'), findsOneWidget);
      expect((await _row(tester, db, DefaultIds.food)).name, 'Food and shopping');
    });

    testWidgets('clearing the budget asks first, then removes it', (tester) async {
      final db = await _pump(
        tester,
        const CategoryEditScreen(categoryId: DefaultIds.transport),
        prepare: _addBudget,
      );
      await tester.enterText(_editable('UGX'), '');
      await tester.tap(find.text('Save category'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Remove the Transport budget?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect((await _row(tester, db, DefaultIds.transport)).monthlyBudget, 200000);

      await tester.tap(find.text('Save category'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Remove'));
      await _settle(tester);
      expect((await _row(tester, db, DefaultIds.transport)).monthlyBudget, isNull);
    });

    testWidgets('Delete says where the entries go, and moves them once confirmed', (tester) async {
      final db = await _pump(
        tester,
        const CategoryEditScreen(categoryId: DefaultIds.transport),
        prepare: (db) async {
          await _addBudget(db);
          await TransactionRepository(db).add(
            TransactionDraft(
              direction: Direction.moneyOut,
              amount: 3000,
              accountId: DefaultIds.mtn,
              occurredAt: DateTime(2026, 11, 19, 8),
              categoryId: DefaultIds.transport,
            ),
          );
        },
      );
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      expect(find.text('Delete Transport?'), findsOneWidget);
      expect(
        find.text(
          'Its 1 entry and any regular payments move to Other. Its budget is removed. This '
          'cannot be undone. To keep it as it is, switch it off on Categories instead.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);

      final left = await tester.runAsync(() async {
        final cats = await db.select(db.categories).get();
        final tx = await db.select(db.transactions).getSingle();
        return (cats.any((c) => c.id == DefaultIds.transport), tx.categoryId);
      });
      expect(left, (false, DefaultIds.other));
    });

    testWidgets('Other cannot be deleted and Fees and tax has no budget or Delete', (tester) async {
      await _pump(tester, const CategoryEditScreen(categoryId: DefaultIds.other));
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Monthly budget'), findsOneWidget);

      await _pump(tester, const CategoryEditScreen(categoryId: DefaultIds.fees));
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Monthly budget'), findsNothing);
    });

    testWidgets('a money-in category has no budget row', (tester) async {
      await _pump(tester, const CategoryEditScreen(categoryId: DefaultIds.salary));
      expect(find.text('Monthly budget'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('edit a category golden, ${b.name}', (tester) async {
        await _pump(
          tester,
          const CategoryEditScreen(categoryId: DefaultIds.transport),
          brightness: b,
          size: const Size(390, 844),
          prepare: _addBudget,
        );
        await expectLater(
          find.byType(CategoryEditScreen),
          matchesGoldenFile('goldens/category_edit_${b.name}.png'),
        );
      });
    }
  });

  group('Categories settings', () {
    for (final b in Brightness.values) {
      testWidgets('categories settings golden, ${b.name}', (tester) async {
        await _pump(
          tester,
          const CategoriesSettingsScreen(),
          brightness: b,
          size: const Size(390, 844),
          prepare: (db) async {
            await _addBudget(db);
            await CategoryRepository(db).setHidden(DefaultIds.health, hidden: true);
          },
        );
        await expectLater(
          find.byType(CategoriesSettingsScreen),
          matchesGoldenFile('goldens/categories_settings_${b.name}.png'),
        );
      });
    }

    testWidgets('each row opens its own edit page and is named for it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const CategoriesSettingsScreen(), prepare: _addBudget);
      expect(find.bySemanticsLabel('Edit Transport, Budget 200,000'), findsOneWidget);
      expect(find.bySemanticsLabel('Edit Food and shopping, No budget'), findsOneWidget);
      // Money-in categories are not listed here: as drawn, one row opens their own screen.
      expect(find.bySemanticsLabel('Edit Salary'), findsNothing);
      expect(find.text('Money-in categories'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Fees and tax'), findsNothing);
      handle.dispose();
    });

    testWidgets('the grip menu moves a category down, and the order is saved', (tester) async {
      final db = await _pump(tester, const CategoriesSettingsScreen());
      await tester.tap(find.bySemanticsLabel('Move Food and shopping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Move up'), findsNothing);
      await tester.tap(find.text('Move down'));
      await _settle(tester);

      final order = await tester.runAsync(
        () async => [
          for (final c in await CategoryRepository(db).watch(CategoryKind.spending).first) c.id,
        ],
      );
      expect(order!.take(2), [DefaultIds.transport, DefaultIds.food]);
    });

    testWidgets('screen readers get move actions on each row', (tester) async {
      final handle = tester.ensureSemantics();
      final db = await _pump(tester, const CategoriesSettingsScreen());
      final transport = find.ancestor(
        of: find.bySemanticsLabel('Edit Transport, No budget'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.customSemanticsActions?.isNotEmpty ?? false),
        ),
      );
      final actions =
          (tester.widget(transport.first) as Semantics).properties.customSemanticsActions!;
      expect(actions.keys.map((a) => a.label), containsAll(['Move up', 'Move down']));
      actions.entries.firstWhere((e) => e.key.label == 'Move up').value();
      await _settle(tester);

      final order = await tester.runAsync(
        () async => [
          for (final c in await CategoryRepository(db).watch(CategoryKind.spending).first) c.id,
        ],
      );
      expect(order!.take(2), [DefaultIds.transport, DefaultIds.food]);
      handle.dispose();
    });
  });
}
