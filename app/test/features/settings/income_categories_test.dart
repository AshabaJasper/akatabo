import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/settings/categories_settings_screen.dart';
import 'package:akatabo/features/settings/category_edit_screen.dart';
import 'package:akatabo/features/settings/income_categories_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

/// The drawn money-in categories, with the default icons and colours.
final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
  categoryRow(
    id: DefaultIds.salary,
    name: 'Salary',
    iconKey: 'work',
    colourToken: 'cat-blue',
    kind: CategoryKind.income,
  ),
  categoryRow(
    id: DefaultIds.business,
    name: 'Business and side work',
    iconKey: 'trend',
    kind: CategoryKind.income,
  ),
  categoryRow(
    id: DefaultIds.gifts,
    name: 'Gifts and family',
    iconKey: 'gift',
    colourToken: 'cat-pink',
    kind: CategoryKind.income,
  ),
  categoryRow(
    id: DefaultIds.refunds,
    name: 'Refunds and money back',
    iconKey: 'repeat',
    colourToken: 'cat-teal',
    kind: CategoryKind.income,
  ),
  categoryRow(
    id: DefaultIds.otherIn,
    name: 'Other money in',
    iconKey: 'dots',
    colourToken: 'cat-slate',
    kind: CategoryKind.income,
  ),
];

Transaction _in(String id, int amount, String cat, int day) => txRow(
  id: id,
  direction: Direction.moneyIn,
  amount: amount,
  categoryId: cat,
  at: DateTime(2026, 11, day, 12),
);

/// The drawn month: salary, three business payments and one gift, plus money out.
final _drawnRows = [
  _in('s', 1200000, DefaultIds.salary, 1),
  _in('b1', 150000, DefaultIds.business, 4),
  _in('b2', 100000, DefaultIds.business, 11),
  _in('b3', 150000, DefaultIds.business, 18),
  _in('g', 50000, DefaultIds.gifts, 8),
  txRow(id: 'o', amount: 45000, at: DateTime(2026, 11, 12, 12)),
];

List<Override> _overrides({
  List<Transaction>? rows,
  Stream<List<Transaction>>? rowStream,
  List<Category>? categories,
  PeriodCalculator calc = const PeriodCalculator(),
}) => [
  storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
  appNowProvider.overrideWithValue(_now),
  periodCalculatorProvider.overrideWithValue(calc),
  allCategoriesProvider.overrideWith((ref) => Stream.value(categories ?? _categories)),
  monthRowsProvider.overrideWith((ref) => rowStream ?? Stream.value(rows ?? _drawnRows)),
];

Future<void> _pump(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides.isEmpty ? _overrides() : overrides,
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const IncomeCategoriesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Money-in categories', () {
    testWidgets('shows each category with its line and amount, and the drawn total', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Money-in categories'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget, reason: 'the back link');

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('+ 1,200,000'), findsOneWidget);
      expect(find.text('Business and side work'), findsOneWidget);
      expect(find.text('3 payments this month'), findsOneWidget);
      expect(find.text('+ 400,000'), findsOneWidget);
      expect(find.text('1 payment this month'), findsNWidgets(2), reason: 'salary and gifts');
      expect(find.text('+ 50,000'), findsOneWidget);
      expect(find.text('Nothing this month'), findsNWidgets(2));
      expect(find.text('0'), findsNWidgets(2));

      expect(find.text('Money in, 1 to 19 November'), findsOneWidget);
      expect(find.text('+ 1,650,000'), findsOneWidget);
      expect(find.text('New money-in category'), findsOneWidget);

      expect(find.text('Food and shopping'), findsNothing);
      expect(find.text('Fees and tax'), findsNothing);
    });

    testWidgets('money in dated after today is not counted yet', (tester) async {
      await _pump(
        tester,
        overrides: _overrides(rows: [..._drawnRows, _in('late', 300000, DefaultIds.salary, 25)]),
      );
      expect(find.text('+ 1,200,000'), findsOneWidget);
      expect(find.text('+ 1,650,000'), findsOneWidget);
    });

    testWidgets('"This month" follows Month starts on', (tester) async {
      await _pump(
        tester,
        overrides: _overrides(
          calc: const PeriodCalculator(monthStartsOn: 25),
          rows: [
            ..._drawnRows,
            _in(
              'oct',
              200000,
              DefaultIds.refunds,
              1,
            ).copyWith(occurredAt: DateTime(2026, 10, 28, 12), localDay: 20261028),
          ],
        ),
      );
      expect(find.text('Money in, 25 October to 19 November'), findsOneWidget);
      expect(find.text('+ 200,000'), findsOneWidget);
      expect(find.text('+ 1,850,000'), findsOneWidget);
    });

    testWidgets('with nothing in yet, it says so instead of a zero total', (tester) async {
      await _pump(tester, overrides: _overrides(rows: const []));
      expect(find.text('Nothing this month'), findsNWidgets(5));
      expect(find.textContaining('Money in, '), findsNothing);
      expect(
        find.text(
          'Nothing has come in from 1 to 19 November yet. Money in that you add is counted here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with no money-in categories it says how to add one', (tester) async {
      await _pump(
        tester,
        overrides: _overrides(
          rows: const [],
          categories: [categoryRow(id: DefaultIds.food, name: 'Food and shopping')],
        ),
      );
      expect(
        find.text('No money-in categories yet. Add one with the button below.'),
        findsOneWidget,
      );
    });

    testWidgets('a load error says what to do, not zeros', (tester) async {
      await _pump(tester, overrides: _overrides(rowStream: Stream.error(StateError('disk'))));
      expect(
        find.text('Money-in categories could not load. Close Akatabo and open it again.'),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a hidden category with money in is listed and marked', (tester) async {
      final cats = [
        for (final c in _categories) c.id == DefaultIds.gifts ? c.copyWith(hidden: true) : c,
      ];
      await _pump(tester, overrides: _overrides(categories: cats));
      expect(find.text('1 payment this month, hidden on Add'), findsOneWidget);
    });

    testWidgets('each row reads as one button to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        find.bySemanticsLabel('Salary, 1 payment this month, UGX 1,200,000 in'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Other money in, Nothing this month, nothing in'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('at 2x text on a 320-wide phone nothing overflows', (tester) async {
      await _pump(tester, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('+ 1,200,000'), findsOneWidget);
    });

    test('the link row names the first three categories', () {
      expect(incomeCategoryWords(_categories), 'Salary, business, gifts');
      expect(incomeCategoryWords(const []), 'None yet');
    });

    test('a name written in capitals keeps them in the link row', () {
      final cats = [
        categoryRow(id: 'a', name: 'Salary', kind: CategoryKind.income),
        categoryRow(id: 'b', name: 'MTN payouts', kind: CategoryKind.income),
        categoryRow(id: 'c', name: 'MoMo agent', kind: CategoryKind.income),
      ];
      expect(incomeCategoryWords(cats), 'Salary, MTN, MoMo');
    });

    for (final b in Brightness.values) {
      testWidgets('golden, ${b.name}', (tester) async {
        await _pump(tester, brightness: b);
        await expectLater(
          find.byType(IncomeCategoriesScreen),
          matchesGoldenFile('goldens/income_categories_${b.name}.png'),
        );
      });
    }
  });

  group('navigation', () {
    testWidgets('Categories links here, and the button opens New money-in category', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 3000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: Routes.settingsCategories,
        routes: [
          GoRoute(
            path: Routes.settingsCategories,
            builder: (_, _) => const CategoriesSettingsScreen(),
          ),
          GoRoute(
            path: Routes.settingsIncomeCategories,
            builder: (_, _) => const IncomeCategoriesScreen(),
          ),
          GoRoute(
            path: Routes.settingsIncomeCategoryNew,
            builder: (_, _) => const CategoryEditScreen.create(
              kind: CategoryKind.income,
              from: CategoryEditFrom.income,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [appDatabaseProvider.overrideWithValue(db), ..._overrides()],
          child: MaterialApp.router(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salary, business, gifts'), findsOneWidget);
      await tester.tap(find.text('Money-in categories'));
      await tester.pumpAndSettle();
      expect(find.text('+ 1,650,000'), findsOneWidget);

      await tester.tap(find.text('New money-in category'));
      await tester.pumpAndSettle();
      expect(find.text('Save category'), findsOneWidget);
      expect(find.text('Money-in categories'), findsOneWidget, reason: 'the back link');
      expect(find.text('Monthly budget'), findsNothing, reason: 'money in has no budget');
      expect(find.text('Delete'), findsNothing);
    });
  });

  group('New money-in category', () {
    Future<void> pumpNew(WidgetTester tester, AppDatabase db) async {
      // Tall, so the lazy list builds the Save button below the icon grid.
      tester.view
        ..physicalSize = const Size(390, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
          ],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            home: const CategoryEditScreen.create(
              kind: CategoryKind.income,
              from: CategoryEditFrom.income,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<List<Category>> named(WidgetTester tester, AppDatabase db, String name) async =>
        (await tester.runAsync(
          () async => (await db.select(db.categories).get()).where((c) => c.name == name).toList(),
        ))!;

    testWidgets('refuses an empty name, then saves a money-in category', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpNew(tester, db);

      await tester.tap(find.text('Save category'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Give the category a name.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Rent from the shop ');
      await tester.pump();
      expect(find.text('Give the category a name.'), findsNothing);
      await tester.tap(find.text('Save category'));
      await settle(tester);

      final saved = await named(tester, db, 'Rent from the shop');
      expect(saved, hasLength(1));
      expect(saved.single.kind, CategoryKind.income);
      expect(saved.single.iconKey, newCategoryIconKey);
      expect(saved.single.colourToken, newCategoryColourToken);
      expect(saved.single.monthlyBudget, isNull);
    });

    testWidgets('the chosen colour and icon are saved', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpNew(tester, db);

      await tester.enterText(find.byType(TextField), 'Rent from the shop');
      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.tap(find.bySemanticsLabel('House'));
      await tester.pump();
      await tester.tap(find.text('Save category'));
      await settle(tester);

      final saved = await named(tester, db, 'Rent from the shop');
      expect((saved.single.colourToken, saved.single.iconKey), ('cat-teal', 'house'));
    });

    testWidgets('Save tapped twice saves one category', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpNew(tester, db);

      await tester.enterText(find.byType(TextField), 'Rent from the shop');
      await tester.tap(find.text('Save category'));
      await tester.tap(find.text('Save category'));
      await settle(tester);

      expect(await named(tester, db, 'Rent from the shop'), hasLength(1));
    });

    testWidgets('a name another category has is refused on the name field', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpNew(tester, db);

      await tester.enterText(find.byType(TextField), ' salary ');
      await tester.tap(find.text('Save category'));
      await settle(tester);

      expect(find.text('Another category already has this name.'), findsOneWidget);
      expect(await named(tester, db, 'salary'), isEmpty);
      expect(find.text('Save category'), findsOneWidget, reason: 'it stays open to fix');
    });
  });

  group('CategoryRepository.add', () {
    test('adds a trimmed category after every other one, and refuses an empty name', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final before = await db.select(db.categories).get();

      final id = await repo.add(
        name: ' Rent ',
        kind: CategoryKind.income,
        iconKey: 'dots',
        colourToken: 'cat-slate',
      );
      final all = await repo.watchAll().first;
      expect(all.last.id, id);
      expect(all.last.name, 'Rent');
      expect(
        all.last.sortOrder,
        greaterThan(before.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b)),
      );
      expect(
        (await repo.watch(CategoryKind.income).first).map((c) => c.id),
        contains(id),
        reason: 'it is offered on Add for money in',
      );

      expect(
        () => repo.add(
          name: '  ',
          kind: CategoryKind.income,
          iconKey: 'dots',
          colourToken: 'cat-slate',
        ),
        throwsArgumentError,
      );
    });

    test('refuses a name another category has, ignoring case and spaces', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      final before = (await db.select(db.categories).get()).length;

      await expectLater(
        repo.add(
          name: ' TRANSPORT ',
          kind: CategoryKind.spending,
          iconKey: 'bus',
          colourToken: 'cat-amber',
        ),
        throwsA(isA<CategoryNameTaken>()),
      );
      expect(await db.select(db.categories).get(), hasLength(before), reason: 'nothing saved');
    });

    test('a new spending category goes last in its kind and can start with a budget', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CategoryRepository(db);

      final id = await repo.add(
        name: 'Rent',
        kind: CategoryKind.spending,
        iconKey: 'house',
        colourToken: 'cat-brown',
        monthlyBudget: 300000,
      );
      final spending = await repo.watch(CategoryKind.spending).first;
      expect(spending.last.id, id);
      expect(
        (spending.last.monthlyBudget, spending.last.budgetCarriesOver, spending.last.budgetWarnAt),
        (300000, false, 80),
      );
      expect(spending.last.budgetSince, isNotNull, reason: 'the budget clock starts');

      expect(
        () => repo.add(
          name: 'Tips',
          kind: CategoryKind.income,
          iconKey: 'gift',
          colourToken: 'cat-pink',
          monthlyBudget: 1000,
        ),
        throwsArgumentError,
        reason: 'money in has no budget',
      );
    });
  });
}
