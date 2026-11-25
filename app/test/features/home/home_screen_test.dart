import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/format/money.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/forecast.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/budgets/budgets_providers.dart';
import 'package:akatabo/features/forecast/forecast_providers.dart';
import 'package:akatabo/features/goals/goals_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/home/home_screen.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:akatabo/features/transactions/transaction_row.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:akatabo/widgets/ak_hidden_amount.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(id: DefaultIds.school, name: 'School fees', iconKey: 'book', colourToken: 'cat-blue'),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', iconKey: 'cash', isSystem: true),
];

final _accounts = [accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)];

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Transaction> latest,
  List<Transaction> month = const [],
  List<Transaction> previous = const [],
  Brightness brightness = Brightness.light,
  Map<String, String> settings = const {},
  List<Override> extra = const [],
  List<Category>? categories,
  List<Goal> goals = const [],
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        // The default calculator: "Month starts on" the 1st, weeks start on Sunday.
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        latestRowsProvider.overrideWith((ref) => Stream.value(latest)),
        monthRowsProvider.overrideWith((ref) => Stream.value(month)),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(previous)),
        allCategoriesProvider.overrideWith((ref) => Stream.value(categories ?? _categories)),
        previousMonthRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        goalsProvider.overrideWith((ref) => Stream.value(goals)),
        allGoalMovesProvider.overrideWith((ref) => Stream.value(const <GoalMove>[])),
        ...extra,
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A filled month: groceries with a fee today, a payment in, school fees, and October.
(Transaction, Transaction, Transaction, Transaction) _filled() {
  final a = txRow(id: 'a', amount: 45000, fee: 1000, day: 20261119, at: _now);
  final b = txRow(
    id: 'b',
    direction: Direction.moneyIn,
    amount: 250000,
    categoryId: DefaultIds.salary,
    day: 20261117,
    at: DateTime(2026, 11, 17, 14, 30),
    description: 'Payment from client',
  );
  final c = txRow(
    id: 'c',
    amount: 200000,
    categoryId: DefaultIds.school,
    day: 20261110,
    at: DateTime(2026, 11, 10, 11),
    description: 'School fees, term two',
  );
  final oct = txRow(id: 'o', amount: 200000, day: 20261012, at: DateTime(2026, 10, 12));
  return (a, b, c, oct);
}

/// Ten days of shopping in November, so the forecast card shows (it needs seven days).
List<Transaction> _tenDays() => [
  for (var d = 1; d <= 10; d++)
    txRow(
      id: 'd$d',
      amount: 8000 + d * 500,
      day: 20261100 + d,
      at: DateTime(2026, 11, d, 10),
      description: 'Shop $d',
    ),
];

/// What the forecast card reads, with no saved forecasts from earlier months.
List<Override> _forecastData(List<Transaction> window) => [
  forecastWindowRowsProvider.overrideWith((ref) => Stream.value(window)),
  activeRegularProvider.overrideWith((ref) => Stream.value(const <RegularPayment>[])),
  forecastSnapshotErrorsProvider.overrideWithValue(const []),
  forecastSnapshotSaverProvider.overrideWithValue(ForecastSnapshotSaver(_noWrite)),
];

Future<void> _noWrite({
  required int periodStart,
  required int takenOn,
  required int point,
  required int low,
  required int high,
  required int spentSoFar,
}) async {}

void main() {
  group('forecast card', () {
    testWidgets('after seven days it says where the month is heading, with its range', (
      tester,
    ) async {
      final days = _tenDays();
      await _pumpHome(
        tester,
        latest: days.take(3).toList(),
        month: days,
        extra: _forecastData(days),
      );
      final f = forecastFor(
        month: const PeriodCalculator().month(_now),
        today: dateOnly(_now),
        monthRows: days,
        windowRows: days,
        regular: const [],
      )!;
      final r = forecastRange(
        spentSoFar: f.spentSoFar,
        everydayDaily: f.everydayDaily,
        spentToday: f.everydayToday,
        daysLeft: f.daysLeft,
        regular: const [],
        dayOfMonth: _now.day,
      );
      expect(find.text('Heading for UGX ${formatShort(r.point)} this month'), findsOneWidget);
      expect(
        find.text(
          'Likely ${formatShort(r.low)} to ${formatShort(r.high)}, most likely '
          '${formatShort(r.point)}. About ${formatAmount(r.point)} more than came in',
        ),
        findsOneWidget,
      );
    });

    testWidgets('before seven days have entries there is no card', (tester) async {
      final (a, b, c, oct) = _filled();
      await _pumpHome(tester, latest: [a, b, c], month: [a, b, c], previous: [oct]);
      expect(find.textContaining('Heading for'), findsNothing);
    });

    testWidgets('with "Forecast the month" off there is no card', (tester) async {
      final days = _tenDays();
      await _pumpHome(
        tester,
        latest: days.take(3).toList(),
        month: days,
        extra: _forecastData(days),
        settings: {SettingKeys.forecastMonth.name: '0'},
      );
      expect(find.textContaining('Heading for'), findsNothing);
      expect(find.textContaining('Likely'), findsNothing);
    });

    testWidgets('Hide amounts hides the forecast figures too', (tester) async {
      final semantics = tester.ensureSemantics();
      final days = _tenDays();
      await _pumpHome(
        tester,
        latest: days.take(3).toList(),
        month: days,
        extra: _forecastData(days),
        settings: {PrivacyKeys.hideAmounts.name: '1'},
      );
      expect(find.text('Heading for UGX $hiddenFigure this month'), findsOneWidget);
      expect(find.text('Likely range hidden'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Forecast for this month. $hiddenFigureLabel. Open the forecast'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  testWidgets('a tablet shows Latest beside the summary; a phone stacks them', (tester) async {
    final (a, b, c, _) = _filled();
    await _pumpHome(tester, latest: [a, b, c], month: [a, b, c], size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    final whereWide = tester.getTopLeft(find.text('Where it went'));
    final latestWide = tester.getTopLeft(find.text('Latest'));
    // Side by side: the Latest title is to the right and about level with the summary.
    expect(latestWide.dx, greaterThan(whereWide.dx));
    expect(latestWide.dy, lessThan(whereWide.dy + 200));

    await _pumpHome(tester, latest: [a, b, c], month: [a, b, c]);
    expect(tester.takeException(), isNull);
    final wherePhone = tester.getTopLeft(find.text('Where it went'));
    final latestPhone = tester.getTopLeft(find.text('Latest'));
    // Stacked: the Latest title sits below the summary, in the same column.
    expect(latestPhone.dx, closeTo(wherePhone.dx, 1));
    expect(latestPhone.dy, greaterThan(wherePhone.dy));
  });

  testWidgets('on a wide window the last Latest row clears the system bar', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    final rows = [
      for (var i = 0; i < 20; i++)
        txRow(
          id: 'r$i',
          amount: 1000 + i,
          day: 20261119,
          at: _now.subtract(Duration(minutes: i)),
        ),
    ];
    await _pumpHome(tester, latest: rows, month: rows, size: const Size(1280, 800));
    final list = find.ancestor(
      of: find.byType(TransactionRow).first,
      matching: find.byType(ListView),
    );
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    // The list ends with the usual gap plus the bar's 48, so the last row can scroll clear of it.
    expect(
      find.descendant(
        of: list,
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == AkSpace.s6 + 48),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the header sets light status-bar icons on a phone only', (tester) async {
    final (a, b, c, _) = _filled();
    Finder regions() => find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byWidgetPredicate((w) => w is AnnotatedRegion<SystemUiOverlayStyle>),
    );
    await _pumpHome(tester, latest: [a, b, c], month: [a, b, c]);
    expect(regions(), findsWidgets);
    await _pumpHome(tester, latest: [a, b, c], month: [a, b, c], size: const Size(1280, 800));
    expect(regions(), findsNothing);
  });

  testWidgets('a switched-off Latest section leaves the rest of Home', (tester) async {
    final (a, b, c, oct) = _filled();
    await _pumpHome(
      tester,
      latest: [a, b, c],
      month: [a, b, c],
      previous: [oct],
      settings: {SettingKeys.homeShowLatest.name: '0'},
    );
    expect(find.text('Latest'), findsNothing);
    expect(find.text('Where it went'), findsOneWidget);
  });

  group('header figures and sections', () {
    // Food has a 100,000 budget. Its 45,000 counts against it; the 1,000 fee goes to Fees
    // and tax, which is never budgeted.
    final budgeted = [
      categoryRow(id: DefaultIds.food, name: 'Food and shopping', monthlyBudget: 100000),
      ..._categories.skip(1),
    ];

    testWidgets('with a budget set, Left in budgets sits between Money in and Fees', (
      tester,
    ) async {
      final (a, b, c, oct) = _filled();
      await _pumpHome(
        tester,
        latest: [a, b, c],
        month: [a, b, c],
        previous: [oct],
        categories: budgeted,
      );
      expect(find.text('Left in budgets'), findsOneWidget);
      expect(find.text('55,000'), findsOneWidget, reason: '100,000 less 45,000 on food');
      final x = [
        for (final label in ['Money in', 'Left in budgets', 'Fees and tax'])
          tester.getTopLeft(find.text(label).first).dx,
      ];
      expect(x[0] < x[1] && x[1] < x[2], isTrue, reason: 'in the drawn order');
    });

    testWidgets('with no budget set there is no budgets figure at all, not a 0', (tester) async {
      final (a, b, c, oct) = _filled();
      await _pumpHome(tester, latest: [a, b, c], month: [a, b, c], previous: [oct]);
      expect(find.text('Left in budgets'), findsNothing);
      expect(find.text('Over budget'), findsNothing);
    });

    testWidgets('spending past every budget reads Over budget, with the overspend', (tester) async {
      final (a, b, c, oct) = _filled();
      await _pumpHome(
        tester,
        latest: [a, b, c],
        month: [a, b, c],
        previous: [oct],
        categories: [
          categoryRow(id: DefaultIds.food, name: 'Food and shopping', monthlyBudget: 40000),
          ..._categories.skip(1),
        ],
      );
      expect(find.text('Over budget'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);
    });

    testWidgets('Savings shows on Home once a goal exists, and its switch hides it', (
      tester,
    ) async {
      final (a, b, c, oct) = _filled();
      Goal goal({DateTime? archivedAt}) => Goal(
        id: 'g1',
        createdAt: _now,
        updatedAt: _now,
        name: 'School fees term 1',
        iconKey: 'book',
        colourToken: 'cat-teal',
        target: 500000,
        remindEvery: GoalRemind.off,
        sortOrder: 0,
        archivedAt: archivedAt,
      );
      Future<void> pump({
        List<Goal> goals = const [],
        Map<String, String> settings = const {},
      }) async {
        // A fresh scope each time: Riverpod keeps the first overrides when a scope rebuilds.
        await tester.pumpWidget(const SizedBox());
        await _pumpHome(
          tester,
          latest: [a, b, c],
          month: [a, b, c],
          previous: [oct],
          goals: goals,
          settings: settings,
        );
      }

      final savings = find.text('School fees term 1');
      await pump();
      expect(find.text('Savings'), findsNothing, reason: 'no goal yet');

      await pump(goals: [goal(archivedAt: _now)]);
      expect(find.text('Savings'), findsNothing, reason: 'only archived goals');

      await pump(goals: [goal()]);
      await tester.dragUntilVisible(savings, find.byType(ListView), const Offset(0, -200));
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('See all'), findsWidgets);

      await pump(goals: [goal()], settings: {SettingKeys.homeShowSavings.name: '0'});
      expect(find.text('Savings'), findsNothing, reason: 'switched off in Settings');
      expect(savings, findsNothing);
    });

    testWidgets('Budgets at a glance is off until chosen, then lists the budgets', (tester) async {
      final (a, b, c, oct) = _filled();
      await _pumpHome(
        tester,
        latest: [a, b, c],
        month: [a, b, c],
        previous: [oct],
        categories: budgeted,
      );
      expect(find.text('Budgets'), findsNothing);
      // A fresh scope: Riverpod keeps the first overrides when the same scope rebuilds.
      await tester.pumpWidget(const SizedBox());

      await _pumpHome(
        tester,
        latest: [a, b, c],
        month: [a, b, c],
        previous: [oct],
        categories: budgeted,
        settings: {SettingKeys.homeShowBudgets.name: '1'},
      );
      await tester.dragUntilVisible(
        find.text('Budgets'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Food and shopping'), findsWidgets);
    });

    testWidgets('the forecast card can be switched off on its own', (tester) async {
      final days = _tenDays();
      await _pumpHome(
        tester,
        latest: days.take(3).toList(),
        month: days,
        extra: _forecastData(days),
        settings: {SettingKeys.homeShowForecast.name: '0'},
      );
      expect(find.textContaining('Heading for'), findsNothing);
      expect(find.text('Where it went'), findsOneWidget);
    });

    testWidgets('three tiles keep one height when a label takes two lines', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      final (a, b, c, oct) = _filled();
      await _pumpHome(
        tester,
        latest: [a, b, c],
        month: [a, b, c],
        previous: [oct],
        categories: budgeted,
      );
      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpAndSettle();
      final heights = {
        for (final label in ['Money in', 'Left in budgets', 'Fees and tax'])
          tester
              .getSize(
                find.ancestor(of: find.text(label).first, matching: find.byType(Material)).first,
              )
              .height,
      };
      expect(heights, hasLength(1), reason: 'equal heights: $heights');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the first day shows three steps, not empty charts', (tester) async {
    await _pumpHome(tester, latest: const []);
    expect(find.text('Three steps to get going'), findsOneWidget);
    expect(find.text('Add something you spent today'), findsOneWidget);
    expect(find.text('UGX 0'), findsOneWidget);
  });

  testWidgets('a filled month shows totals, the split and the latest entries', (tester) async {
    final (a, b, c, oct) = _filled();
    await _pumpHome(tester, latest: [a, b, c], month: [a, b, c], previous: [oct]);

    expect(find.text('Money out, 1 to 19 November'), findsOneWidget);
    // 45,000 + 1,000 fee, plus 200,000 for school: 246,000 money out.
    expect(find.text('UGX 246,000'), findsOneWidget);
    // 246,000 against 200,000 over the same days last October: 23% up.
    expect(find.text('23% above this point in October'), findsOneWidget);
    expect(find.text('250k'), findsOneWidget, reason: 'money in, as a short figure');
    expect(
      find.text('1,000'),
      findsNWidgets(2),
      reason: 'fees and tax: the tile and the Fees row of the split',
    );
    expect(find.text('Where it went'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Payment from client'), findsOneWidget);
    expect(find.text('Three steps to get going'), findsNothing);
  });

  testWidgets('the status bar over the green header has light icons in light theme', (
    tester,
  ) async {
    await _pumpHome(tester, latest: const []);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });

  // One pump per test: a second ProviderScope in the same test keeps the first one's state.
  for (final b in Brightness.values) {
    testWidgets('first-day home golden, ${b.name}', (tester) async {
      await _pumpHome(tester, latest: const [], brightness: b);
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_first_day_${b.name}.png'),
      );
    });

    testWidgets('home with the forecast card golden, ${b.name}', (tester) async {
      final days = _tenDays();
      await _pumpHome(
        tester,
        latest: days.reversed.take(3).toList(),
        month: days,
        extra: _forecastData(days),
        brightness: b,
      );
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_forecast_${b.name}.png'),
      );
    });

    testWidgets('home golden, ${b.name}', (tester) async {
      final (a, x, c, oct) = _filled();
      await _pumpHome(tester, latest: [a, x, c], month: [a, x, c], previous: [oct], brightness: b);
      await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home_${b.name}.png'));
    });
  }
}
