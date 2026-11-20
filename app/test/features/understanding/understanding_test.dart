import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/categories/categories_screen.dart';
import 'package:akatabo/features/categories/category_detail_screen.dart';
import 'package:akatabo/features/fees/fees_screen.dart';
import 'package:akatabo/features/forecast/forecast_providers.dart';
import 'package:akatabo/features/forecast/forecast_screen.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/insights/insights_providers.dart';
import 'package:akatabo/features/insights/insights_screen.dart';
import 'package:akatabo/features/regular/regular_new_screen.dart';
import 'package:akatabo/features/regular/regular_payments_screen.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(id: DefaultIds.school, name: 'School fees', iconKey: 'book', colourToken: 'cat-blue'),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', iconKey: 'cash', isSystem: true),
];

final _accounts = [accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)];

/// Every account, with Cash switched off after it was used.
final _allAccounts = [
  ..._accounts,
  accountRow(id: DefaultIds.cash, name: 'Cash', kind: AccountKind.cash, enabled: false),
];

class _MockRegularRepo extends Mock implements RegularPaymentRepository {}

/// Pumps one screen at phone size with the given data. Each test pumps once, because a
/// second ProviderScope in the same test keeps the first one's state.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> data = const [],
  Brightness brightness = Brightness.light,
  Map<String, String> settings = const {},
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        allAccountsProvider.overrideWith((ref) => Stream.value(_allAccounts)),
        ...data,
      ],
      child: MaterialApp(theme: buildAkTheme(brightness, const AkAppearance()), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rows each screen reads. Empty lists are the empty state.
List<Override> _data({
  List<Transaction> month = const [],
  List<Transaction> previous = const [],
  List<Transaction> window = const [],
  List<RegularPayment> regular = const [],
  List<Override> extra = const [],
}) => [
  monthRowsProvider.overrideWith((ref) => Stream.value(month)),
  previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(previous)),
  forecastWindowRowsProvider.overrideWith((ref) => Stream.value(window)),
  activeRegularProvider.overrideWith((ref) => Stream.value(regular)),
  insightsRowsProvider.overrideWith((ref, period) => Stream.value(month)),
  ...extra,
];

/// Ten days of spending in November, so a forecast is shown (it needs seven days).
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

void main() {
  group('Insights', () {
    testWidgets('an empty period says nothing was spent or received', (tester) async {
      await _pump(tester, const InsightsScreen(), data: _data());
      expect(find.text('Nothing spent or received in this period yet.'), findsOneWidget);
    });

    testWidgets('a period with entries shows the spent figure and cash flow', (tester) async {
      await _pump(tester, const InsightsScreen(), data: _data(month: _tenDays()));
      expect(find.textContaining('Spent,'), findsOneWidget);
      expect(find.text('Cash flow'), findsOneWidget);
    });

    testWidgets('Forecast is offered while "Forecast the month" is on, the default', (
      tester,
    ) async {
      await _pump(tester, const InsightsScreen(), data: _data());
      await tester.scrollUntilVisible(find.text('Coming up'), 200);
      expect(find.text('Forecast'), findsOneWidget);
    });

    testWidgets('with "Forecast the month" off, Insights offers no Forecast', (tester) async {
      await _pump(
        tester,
        const InsightsScreen(),
        data: _data(),
        settings: {SettingKeys.forecastMonth.name: '0'},
      );
      await tester.scrollUntilVisible(find.text('Coming up'), 200);
      expect(find.text('Forecast'), findsNothing);
      expect(find.text('Fees and tax'), findsOneWidget);
    });

    testWidgets('insights chart, light', (tester) async {
      await _pump(tester, const InsightsScreen(), data: _data(month: _tenDays()));
      await expectLater(
        find.byType(InsightsScreen),
        matchesGoldenFile('goldens/insights_loaded_light.png'),
      );
    });
  });

  group('Categories', () {
    testWidgets('an empty month says nothing is grouped yet', (tester) async {
      await _pump(tester, const CategoriesScreen(), data: _data());
      expect(
        find.text('Nothing spent this month yet. Entries you add are grouped here.'),
        findsOneWidget,
      );
    });

    testWidgets('a month lists its categories by amount', (tester) async {
      final month = [
        txRow(id: 'f', amount: 45000, day: 20261119, at: _now),
        txRow(
          id: 's',
          amount: 200000,
          categoryId: DefaultIds.school,
          day: 20261110,
          at: DateTime(2026, 11, 10, 11),
        ),
      ];
      await _pump(tester, const CategoriesScreen(), data: _data(month: month));
      expect(find.text('School fees'), findsOneWidget);
      expect(find.text('Food and shopping'), findsOneWidget);
    });
  });

  group('Category detail', () {
    testWidgets('a category with nothing this month says so', (tester) async {
      await _pump(tester, const CategoryDetailScreen(categoryId: DefaultIds.food), data: _data());
      expect(find.text('Nothing spent on food and shopping this month yet.'), findsOneWidget);
    });

    testWidgets('a category with entries shows its weeks and payees', (tester) async {
      await _pump(
        tester,
        const CategoryDetailScreen(categoryId: DefaultIds.food),
        data: _data(month: _tenDays()),
      );
      expect(find.text('WEEK BY WEEK'), findsOneWidget);
      expect(find.text('WHAT IT WENT ON'), findsOneWidget);
    });
  });

  group('Fees and tax', () {
    testWidgets('no fees this month explains where they appear', (tester) async {
      await _pump(tester, const FeesScreen(), data: _data());
      expect(
        find.text('No fees or tax this month. They appear here when an entry has one.'),
        findsOneWidget,
      );
    });

    testWidgets('an entry with a fee shows the split and the accounts', (tester) async {
      final month = [txRow(id: 'a', amount: 45000, fee: 1000, day: 20261119, at: _now)];
      await _pump(tester, const FeesScreen(), data: _data(month: month));
      expect(find.text('Sending money'), findsOneWidget);
      expect(find.text('BY ACCOUNT'), findsOneWidget);
    });
  });

  testWidgets('a cash-out to a switched-off Cash account is still withdrawing cash', (
    tester,
  ) async {
    final month = [
      txRow(
        id: 'w',
        direction: Direction.transfer,
        amount: 100000,
        toAccountId: DefaultIds.cash,
        fee: 2000,
        tax: 500,
        day: 20261118,
        at: DateTime(2026, 11, 18, 10),
      ),
    ];
    await _pump(tester, const FeesScreen(), data: _data(month: month));
    expect(find.text('Withdrawing cash'), findsOneWidget);
    expect(find.text('Sending money'), findsNothing);
    expect(find.text('Tax on withdrawals'), findsOneWidget);
    expect(find.text('On withdrawals'), findsOneWidget);
  });

  group('Forecast', () {
    testWidgets('before seven days have entries, it says how many more are needed', (tester) async {
      final three = [
        for (var d = 1; d <= 3; d++)
          txRow(id: 'g$d', amount: 8000, day: 20261100 + d, at: DateTime(2026, 11, d, 10)),
      ];
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: three, window: three),
      );
      expect(
        find.text('A forecast appears once seven days this month have entries. 4 more to go.'),
        findsOneWidget,
      );
    });

    testWidgets('once seven days have entries, the forecast and its range show', (tester) async {
      final days = _tenDays();
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days),
      );
      expect(find.textContaining('Most likely between'), findsOneWidget);
      expect(find.text('HOW IT ADDS UP'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('forecast painter golden, ${b.name}', (tester) async {
        final days = _tenDays();
        await _pump(
          tester,
          const ForecastScreen(),
          data: _data(month: days, window: days),
          brightness: b,
        );
        await expectLater(
          find.byType(ForecastScreen),
          matchesGoldenFile('goldens/forecast_shown_${b.name}.png'),
        );
      });
    }
  });

  group('Regular payments', () {
    testWidgets('nothing repeating yet has an empty note', (tester) async {
      await _pump(tester, const RegularPaymentsScreen(), data: _data());
      expect(
        find.text(
          'Nothing repeating yet. Add a bill you pay every week or month, and it comes up here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a payment due this month shows its total and reading', (tester) async {
      final repo = _MockRegularRepo();
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [regularRow(id: 'r1', nextDueOn: 20261125)],
          extra: [regularRepoOverride(repo)],
        ),
      );
      expect(find.text('Data bundle'), findsOneWidget);
      expect(find.text('UGX 10,000'), findsOneWidget);
    });

    testWidgets('removing a payment asks first, then dismisses it', (tester) async {
      final repo = _MockRegularRepo();
      when(() => repo.dismiss(any())).thenAnswer((_) async {});
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [regularRow(id: 'r1', nextDueOn: 20261125)],
          extra: [regularRepoOverride(repo)],
        ),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Data bundle?'), findsOneWidget);
      verifyNever(() => repo.dismiss(any()));

      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Remove')),
      );
      await tester.pumpAndSettle();
      verify(() => repo.dismiss('r1')).called(1);
    });

    testWidgets('a new payment needs a name and an amount above zero', (tester) async {
      final repo = _MockRegularRepo();
      await _pump(
        tester,
        const RegularNewScreen(),
        data: _data(extra: [regularRepoOverride(repo)]),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Give it a name, such as Water bill.'), findsOneWidget);
      verifyNever(
        () => repo.add(
          label: any(named: 'label'),
          amount: any(named: 'amount'),
          intervalDays: any(named: 'intervalDays'),
          nextDueOn: any(named: 'nextDueOn'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });

    testWidgets('a valid new payment is saved to Bills', (tester) async {
      final repo = _MockRegularRepo();
      when(
        () => repo.add(
          label: any(named: 'label'),
          amount: any(named: 'amount'),
          intervalDays: any(named: 'intervalDays'),
          nextDueOn: any(named: 'nextDueOn'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => 'r-new');
      await _pump(
        tester,
        const RegularNewScreen(),
        data: _data(extra: [regularRepoOverride(repo)]),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Water bill');
      await tester.enterText(find.byType(TextField).at(1), '46000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(
        () => repo.add(
          label: 'Water bill',
          amount: 46000,
          intervalDays: 30,
          nextDueOn: any(named: 'nextDueOn'),
          categoryId: DefaultIds.bills,
        ),
      ).called(1);
    });
  });
}

Override regularRepoOverride(RegularPaymentRepository repo) =>
    regularPaymentRepositoryProvider.overrideWithValue(repo);
