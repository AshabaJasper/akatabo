import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/budgets/budget_edit_screen.dart';
import 'package:akatabo/features/budgets/budgets_providers.dart';
import 'package:akatabo/features/budgets/budgets_screen.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

/// The drawn Budgets screen: Transport over, Food nearly used, Bills a little ahead, and
/// School fees with spending but no budget.
final _categories = [
  categoryRow(
    id: DefaultIds.transport,
    name: 'Transport',
    iconKey: 'car',
    colourToken: 'cat-blue',
    monthlyBudget: 200000,
  ),
  categoryRow(id: DefaultIds.food, name: 'Food and shopping', monthlyBudget: 450000),
  categoryRow(id: DefaultIds.bills, name: 'Bills', monthlyBudget: 250000),
  categoryRow(id: DefaultIds.school, name: 'School fees', iconKey: 'book'),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
];

final _accounts = [accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)];

class _MockCategoryRepo extends Mock implements CategoryRepository {}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> data = const [],
  List<Category>? categories,
  Brightness brightness = Brightness.light,
  DateTime? now,
  PeriodCalculator calc = const PeriodCalculator(),
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(now ?? _now),
        periodCalculatorProvider.overrideWithValue(calc),
        allCategoriesProvider.overrideWith((ref) => Stream.value(categories ?? _categories)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        ...data,
      ],
      child: MaterialApp(theme: buildAkTheme(brightness, const AkAppearance()), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _rows({
  List<Transaction> month = const [],
  List<Transaction> previous = const [],
  List<Transaction> history = const [],
  List<Override> extra = const [],
}) => [
  monthRowsProvider.overrideWith((ref) => Stream.value(month)),
  previousMonthRowsProvider.overrideWith((ref) => Stream.value(previous)),
  budgetHistoryRowsProvider.overrideWith((ref) => Stream.value(history)),
  ...extra,
];

/// This month's spending: Transport over its budget, Food near it, Bills under it, and School
/// fees with nothing budgeted.
List<Transaction> _thisMonth() => [
  txRow(id: 't', amount: 236000, categoryId: DefaultIds.transport, day: 20261118, at: _now),
  txRow(id: 'f', amount: 412000, day: 20261117, at: _now),
  txRow(id: 'b', amount: 198000, categoryId: DefaultIds.bills, day: 20261116, at: _now),
  txRow(id: 's', amount: 350000, categoryId: DefaultIds.school, day: 20261110, at: _now),
];

/// Six months of Transport spending, oldest first: the drawn sheet's history.
List<Transaction> _transportHistory() {
  const amounts = [182000, 205000, 196000, 228000, 244000, 236000];
  const months = [5, 6, 7, 8, 9, 10];
  return [
    for (var i = 0; i < amounts.length; i++)
      txRow(
        id: 'h$i',
        amount: amounts[i],
        categoryId: DefaultIds.transport,
        day: 20260000 + months[i] * 100 + 15,
        at: DateTime(2026, months[i], 15, 12),
      ),
  ];
}

void main() {
  group('Budgets', () {
    testWidgets('with no budgets and no spending, it says how to start', (tester) async {
      await _pump(
        tester,
        const BudgetsScreen(),
        data: _rows(),
        categories: [categoryRow(id: DefaultIds.food, name: 'Food')],
      );
      expect(
        find.text(
          'No budgets yet. Set one for a category you want to keep an eye on, and it shows here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Choose a category'), findsOneWidget, reason: 'the next step is offered');
    });

    testWidgets('the overall figure and the day allowance match the drawn screen', (tester) async {
      await _pump(tester, const BudgetsScreen(), data: _rows(month: _thisMonth()));
      expect(find.text('Left to spend in November'), findsOneWidget);
      expect(find.text('UGX 54,000'), findsOneWidget);
      expect(find.text('A day, for 11 days'), findsOneWidget);
      expect(find.text('4,900'), findsOneWidget);
      expect(find.text('846,000 of 900,000 spent'), findsOneWidget);
    });

    testWidgets('each budget shows its spend and its status in words', (tester) async {
      await _pump(tester, const BudgetsScreen(), data: _rows(month: _thisMonth()));
      expect(find.text('236,000 of 200,000'), findsOneWidget);
      expect(find.text('Over by 36,000'), findsOneWidget);
      expect(find.text('Nearly used'), findsOneWidget, reason: 'Food, 92% used');
      expect(find.text('A little ahead'), findsOneWidget, reason: 'Bills, 79% used');
    });

    testWidgets('a category with spending and no budget offers to set one', (tester) async {
      await _pump(tester, const BudgetsScreen(), data: _rows(month: _thisMonth()));
      expect(find.text('School fees has no budget'), findsOneWidget);
      expect(find.text('You spent 350,000 on it this month'), findsOneWidget);
      expect(find.text('Set one'), findsOneWidget);
    });

    testWidgets('fees and tax are never offered as a budget', (tester) async {
      final month = [txRow(id: 'fee', amount: 45000, fee: 1000, day: 20261118, at: _now)];
      await _pump(tester, const BudgetsScreen(), data: _rows(month: month));
      expect(find.text('Fees and tax has no budget'), findsNothing);
    });

    testWidgets('pace follows the budget month when it starts on the 25th', (tester) async {
      // 19 November sits in 25 October to 24 November: day 26 of 31, not day 19. 70% spent
      // on 84% of the month is on track; read against the 19th it would look ahead.
      await _pump(
        tester,
        const BudgetsScreen(),
        calc: const PeriodCalculator(monthStartsOn: 25),
        categories: [categoryRow(id: DefaultIds.food, name: 'Food', monthlyBudget: 100000)],
        data: _rows(
          month: [txRow(id: 'f', amount: 70000, day: 20261110, at: _now)],
        ),
      );
      expect(find.text('On track'), findsOneWidget);
      expect(find.text('A little ahead'), findsNothing);
    });

    testWidgets("carry-over adds last month's unspent part once a full month has passed", (
      tester,
    ) async {
      await _pump(
        tester,
        const BudgetsScreen(),
        categories: [
          categoryRow(
            id: DefaultIds.transport,
            name: 'Transport',
            monthlyBudget: 200000,
            budgetCarriesOver: true,
            budgetSince: 20260901,
          ),
        ],
        data: _rows(
          month: [txRow(id: 't', amount: 100000, categoryId: DefaultIds.transport, day: 20261110)],
          previous: [
            txRow(id: 'p', amount: 150000, categoryId: DefaultIds.transport, day: 20261015),
          ],
        ),
      );
      expect(find.text('100,000 of 250,000'), findsOneWidget);
    });

    testWidgets('a budget set this month carries nothing in yet', (tester) async {
      await _pump(
        tester,
        const BudgetsScreen(),
        categories: [
          categoryRow(
            id: DefaultIds.transport,
            name: 'Transport',
            monthlyBudget: 200000,
            budgetCarriesOver: true,
            budgetSince: 20261105,
          ),
        ],
        data: _rows(
          month: [txRow(id: 't', amount: 100000, categoryId: DefaultIds.transport, day: 20261110)],
          previous: [
            txRow(id: 'p', amount: 150000, categoryId: DefaultIds.transport, day: 20261015),
          ],
        ),
      );
      expect(find.text('100,000 of 200,000'), findsOneWidget);
    });

    testWidgets('on the last day of the month it says what is left for today', (tester) async {
      await _pump(
        tester,
        const BudgetsScreen(),
        now: DateTime(2026, 11, 30, 9),
        data: _rows(month: _thisMonth()),
      );
      expect(find.text('Left for today'), findsOneWidget);
      expect(find.textContaining('for 0 days'), findsNothing);
    });

    testWidgets('a database error says so instead of loading forever', (tester) async {
      await _pump(
        tester,
        const BudgetsScreen(),
        data: [
          monthRowsProvider.overrideWith((ref) => Stream.error(StateError('disk'))),
          previousMonthRowsProvider.overrideWith((ref) => Stream.value(const [])),
          budgetHistoryRowsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
      );
      expect(find.text('Budgets could not load. Close Akatabo and open it again.'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('budgets golden, ${b.name}', (tester) async {
        await _pump(
          tester,
          const BudgetsScreen(),
          data: _rows(month: _thisMonth()),
          brightness: b,
        );
        await expectLater(
          find.byType(BudgetsScreen),
          matchesGoldenFile('goldens/budgets_${b.name}.png'),
        );
      });
    }
  });

  group('Set a budget', () {
    testWidgets('it suggests the amount that covered five of six months', (tester) async {
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(history: _transportHistory()),
      );
      expect(find.text('Transport budget'), findsOneWidget);
      expect(find.text('240,000 suggested'), findsOneWidget);
      expect(
        find.text(
          'You went over 200,000 in 4 of the last 6 months. '
          'A budget of 240,000 would have covered 5 of them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the six months are labelled, oldest first', (tester) async {
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(history: _transportHistory()),
      );
      for (final m in ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']) {
        expect(find.text(m), findsOneWidget);
      }
    });

    testWidgets('without three months of spending there is no suggestion', (tester) async {
      await _pump(tester, const BudgetEditScreen(categoryId: DefaultIds.school), data: _rows());
      expect(
        find.text('A suggestion appears after three months with spending in School fees.'),
        findsOneWidget,
      );
    });

    testWidgets('saving the suggested amount writes the budget and closes the screen', (
      tester,
    ) async {
      final repo = _MockCategoryRepo();
      when(
        () => repo.setBudget(
          any(),
          monthlyBudget: any(named: 'monthlyBudget'),
          carriesOver: any(named: 'carriesOver'),
          warnAt: any(named: 'warnAt'),
        ),
      ).thenAnswer((_) async {});
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(
          history: _transportHistory(),
          extra: [categoryRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.tap(find.text('240,000 suggested'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();
      verify(
        () => repo.setBudget(
          DefaultIds.transport,
          monthlyBudget: 240000,
          carriesOver: false,
          warnAt: 80,
        ),
      ).called(1);
    });

    testWidgets('an amount of zero is refused', (tester) async {
      final repo = _MockCategoryRepo();
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(extra: [categoryRepositoryProvider.overrideWithValue(repo)]),
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount above zero.'), findsOneWidget);
      verifyNever(
        () => repo.setBudget(
          any(),
          monthlyBudget: any(named: 'monthlyBudget'),
          carriesOver: any(named: 'carriesOver'),
          warnAt: any(named: 'warnAt'),
        ),
      );
    });

    testWidgets('removing a budget asks first, then clears it', (tester) async {
      final repo = _MockCategoryRepo();
      when(
        () => repo.setBudget(
          any(),
          monthlyBudget: any(named: 'monthlyBudget'),
          carriesOver: any(named: 'carriesOver'),
          warnAt: any(named: 'warnAt'),
        ),
      ).thenAnswer((_) async {});
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(extra: [categoryRepositoryProvider.overrideWithValue(repo)]),
      );
      await tester.tap(find.text('Remove budget'));
      await tester.pumpAndSettle();
      expect(find.text('Remove the Transport budget?'), findsOneWidget);
      verifyNever(
        () => repo.setBudget(
          any(),
          monthlyBudget: any(named: 'monthlyBudget'),
          carriesOver: any(named: 'carriesOver'),
          warnAt: any(named: 'warnAt'),
        ),
      );
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')),
      );
      await tester.pumpAndSettle();
      verify(
        () => repo.setBudget(
          DefaultIds.transport,
          monthlyBudget: null,
          carriesOver: false,
          warnAt: 80,
        ),
      ).called(1);
    });

    testWidgets('a failed removal says so and keeps the screen open', (tester) async {
      final repo = _MockCategoryRepo();
      when(
        () => repo.setBudget(
          any(),
          monthlyBudget: any(named: 'monthlyBudget'),
          carriesOver: any(named: 'carriesOver'),
          warnAt: any(named: 'warnAt'),
        ),
      ).thenThrow(StateError('disk full'));
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: _rows(extra: [categoryRepositoryProvider.overrideWithValue(repo)]),
      );
      await tester.tap(find.text('Remove budget'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')),
      );
      await tester.pumpAndSettle();
      expect(find.text('The budget could not be removed. Try again.'), findsOneWidget);
      expect(find.text('Transport budget'), findsOneWidget);
    });

    testWidgets('a database error says so instead of loading forever', (tester) async {
      await _pump(
        tester,
        const BudgetEditScreen(categoryId: DefaultIds.transport),
        data: [
          monthRowsProvider.overrideWith((ref) => Stream.value(const [])),
          previousMonthRowsProvider.overrideWith((ref) => Stream.value(const [])),
          budgetHistoryRowsProvider.overrideWith((ref) => Stream.error(StateError('disk'))),
        ],
      );
      expect(
        find.text('This budget could not load. Close Akatabo and open it again.'),
        findsOneWidget,
      );
    });
  });
}
