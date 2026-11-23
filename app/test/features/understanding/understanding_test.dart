import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/format/money.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/forecast.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/budgets/budgets_providers.dart';
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
import 'package:akatabo/features/settings/category_edit_screen.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_switch.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:akatabo/widgets/charts/cumulative_line.dart';
import 'package:akatabo/widgets/charts/stacked_bars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_notifications.dart';
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
  PeriodCalculator calc = const PeriodCalculator(),
  AkAppearance appearance = const AkAppearance(),
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
        appearanceProvider.overrideWithValue(appearance),
        appNowProvider.overrideWithValue(_now),
        periodCalculatorProvider.overrideWithValue(calc),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        allAccountsProvider.overrideWith((ref) => Stream.value(_allAccounts)),
        ...data,
      ],
      child: MaterialApp(theme: buildAkTheme(brightness, appearance), home: screen),
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
  List<double> snapshotErrors = const [],
  ForecastSnapshotSaver? saver,
  List<Transaction> older = const [],
  List<SnapshotPoint> history = const [],
}) => [
  forecastHistoryProvider.overrideWithValue(history),
  monthRowsProvider.overrideWith((ref) => Stream.value(month)),
  budgetHistoryRowsProvider.overrideWith((ref) => Stream.value(older)),
  previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(previous)),
  forecastWindowRowsProvider.overrideWith((ref) => Stream.value(window)),
  activeRegularProvider.overrideWith((ref) => Stream.value(regular)),
  insightsRowsProvider.overrideWith((ref, period) => Stream.value(month)),
  forecastSnapshotErrorsProvider.overrideWithValue(snapshotErrors),
  forecastSnapshotSaverProvider.overrideWithValue(saver ?? ForecastSnapshotSaver(_noWrite)),
  ...extra,
];

Future<void> _noWrite({
  required int periodStart,
  required int takenOn,
  required int point,
  required int low,
  required int high,
  required int spentSoFar,
}) async {}

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

    testWidgets('Hide amounts dots the spent figure, cash flow and their spoken summaries', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final month = _tenDays();
      final out = month.fold<int>(0, (a, t) => a + t.amount);
      await _pump(
        tester,
        const InsightsScreen(),
        data: _data(month: month),
        settings: {PrivacyKeys.hideAmounts.name: '1'},
      );
      expect(find.text(formatUgx(out)), findsNothing);
      await tester.scrollUntilVisible(find.text('Cash flow'), 200);
      expect(find.text(formatAmount(out)), findsNothing);
      expect(find.bySemanticsLabel(RegExp(formatAmount(out))), findsNothing);
      semantics.dispose();
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

    testWidgets('Day by day fills the days so far by spending and outlines the rest', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final month = [
        txRow(id: 'a', amount: 5000, day: 20261103, at: DateTime(2026, 11, 3, 9)),
        txRow(id: 'b', amount: 90000, day: 20261116, at: DateTime(2026, 11, 16, 9)),
        txRow(id: 'c', amount: 12000, day: 20261119, at: _now),
      ];
      await _pump(tester, const CategoriesScreen(), data: _data(month: month));
      await tester.dragUntilVisible(
        find.text('Day by day'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      final c = tester.element(find.byType(CategoriesScreen)).colors;
      BoxDecoration box(int day) =>
          tester.widget<DecoratedBox>(find.byKey(ValueKey('day-$day'))).decoration as BoxDecoration;

      // The month's biggest day is the darkest, a day with nothing is the lightest, and the
      // days after today are an outline with no fill.
      expect(box(16).color, c.heat4);
      expect(box(5).color, c.heat0);
      expect(box(20).color, isNull);
      expect(box(20).border, isNotNull);
      expect(find.byKey(const ValueKey('day-30')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-31')), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Calendar of November. Spending was highest on the 16th. '
          'Days after the 19th are still empty.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
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

    testWidgets('Edit opens Edit a category, whose back link names the category', (tester) async {
      final router = GoRouter(
        initialLocation: Routes.category(DefaultIds.food),
        routes: [
          GoRoute(
            path: '${Routes.categories}/:id',
            builder: (_, state) => CategoryDetailScreen(categoryId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '${Routes.settingsCategories}/:id/edit',
            builder: (_, state) => CategoryEditScreen(
              categoryId: state.pathParameters['id']!,
              from: CategoryEditFrom.parse(state.uri.queryParameters['from']),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view
        ..physicalSize = const Size(390, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
            appNowProvider.overrideWithValue(_now),
            periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
            allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
            ..._data(),
          ],
          child: MaterialApp.router(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Save category'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to Food and shopping'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Fees and tax has no Edit', (tester) async {
      await _pump(tester, const CategoryDetailScreen(categoryId: DefaultIds.fees), data: _data());
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a category that is gone says so instead of showing Other', (tester) async {
      await _pump(tester, const CategoryDetailScreen(categoryId: 'deleted'), data: _data());
      expect(find.text('This category is no longer here.'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Other'), findsNothing);
    });

    testWidgets('the Edit link is a 44px target', (tester) async {
      await _pump(tester, const CategoryDetailScreen(categoryId: DefaultIds.food), data: _data());
      expect(
        tester.getSize(find.ancestor(of: find.text('Edit'), matching: find.byType(InkWell))).height,
        greaterThanOrEqualTo(44),
      );
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

    testWidgets('under Category colours: One colour, the three fee parts stay apart', (
      tester,
    ) async {
      final month = [txRow(id: 'a', amount: 45000, fee: 1000, tax: 500, day: 20261119, at: _now)];
      await _pump(
        tester,
        const FeesScreen(),
        data: _data(month: month),
        appearance: const AkAppearance(categoryColours: AkCategoryColours.oneColour),
      );
      final parts = tester.widget<StackedBars>(find.byType(StackedBars)).parts;
      expect(parts.map((p) => p.colour).toSet(), hasLength(3));
    });

    testWidgets('an entry with a fee shows the split and the accounts', (tester) async {
      final month = [txRow(id: 'a', amount: 45000, fee: 1000, day: 20261119, at: _now)];
      await _pump(tester, const FeesScreen(), data: _data(month: month));
      expect(find.text('Sending money'), findsOneWidget);
      expect(find.text('BY ACCOUNT'), findsOneWidget);
    });

    // October: a 2,000 sending fee. August: a 4,000 sending fee. November: 1,000.
    final older = [
      txRow(id: 'o', amount: 30000, fee: 2000, day: 20261012, at: DateTime(2026, 10, 12)),
      txRow(id: 'g', amount: 30000, fee: 4000, day: 20260803, at: DateTime(2026, 8, 3)),
    ];
    final thisMonth = [txRow(id: 'a', amount: 45000, fee: 1000, day: 20261119, at: _now)];

    testWidgets('six months of fees stand as bars, June to this month', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const FeesScreen(),
        data: _data(month: thisMonth, older: older),
      );
      for (final m in ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(find.text('4k'), findsOneWidget, reason: 'August over its bar');
      expect(
        find.bySemanticsLabel(
          'Fees and tax for six months. June 0, July 0, August 4,000, September 0, '
          'October 2,000, November 1,000 so far.',
        ),
        findsOneWidget,
      );
      // Heights follow the amounts: August is the tallest, twice October.
      final aug = tester.getSize(find.byKey(const ValueKey('Aug-Sending'))).height;
      final oct = tester.getSize(find.byKey(const ValueKey('Oct-Sending'))).height;
      expect(aug, closeTo(oct * 2, 0.5));
      semantics.dispose();
    });

    testWidgets('with Hide amounts on, the bars stay and their figures do not', (tester) async {
      await _pump(
        tester,
        const FeesScreen(),
        data: _data(month: thisMonth, older: older),
        settings: {PrivacyKeys.hideAmounts.name: '1'},
      );
      expect(find.text('4k'), findsNothing);
      expect(find.byKey(const ValueKey('Aug-Sending')), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('fees golden, ${b.name}', (tester) async {
        await _pump(
          tester,
          const FeesScreen(),
          data: _data(month: thisMonth, older: older),
          brightness: b,
        );
        await expectLater(find.byType(FeesScreen), matchesGoldenFile('goldens/fees_${b.name}.png'));
      });
    }
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
      expect(find.text('HOW IT ADDS UP'), findsOneWidget);
    });

    testWidgets('the range is shown in words with its numbers, as worked out on the phone', (
      tester,
    ) async {
      final days = _tenDays();
      final saved = <(int, int, int)>[];
      Future<void> write({
        required int periodStart,
        required int takenOn,
        required int point,
        required int low,
        required int high,
        required int spentSoFar,
      }) async => saved.add((low, point, high));
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days, saver: ForecastSnapshotSaver(write)),
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
      expect(r.point, f.point, reason: 'the range keeps the Phase 3 point');
      expect(r.low, lessThan(r.high));
      expect(
        find.textContaining(
          'Likely ${formatUgx(r.low)} to ${formatUgx(r.high)}, most likely ${formatUgx(r.point)}.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('replays end inside it'), findsOneWidget);
      expect(find.textContaining('earlier month'), findsNothing, reason: 'no snapshot yet');
      expect(saved, [(r.low, r.point, r.high)], reason: 'the shown range is saved once');
    });

    testWidgets('earlier forecasts that were out say so beside the range', (tester) async {
      final days = _tenDays();
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days, snapshotErrors: const [0.3, -0.2]),
      );
      expect(
        find.textContaining('how far your forecasts were out in 2 earlier months'),
        findsOneWidget,
      );
    });

    testWidgets('How close it has been sets each earlier forecast beside what was spent', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final days = _tenDays();
      const history = [
        SnapshotPoint(periodStart: 20260801, dayInPeriod: 19, point: 1520000, actual: 1490000),
        SnapshotPoint(periodStart: 20260901, dayInPeriod: 19, point: 1610000, actual: 1660000),
        SnapshotPoint(periodStart: 20261001, dayInPeriod: 19, point: 1710000, actual: 1690000),
      ];
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days, history: history),
      );
      await tester.dragUntilVisible(
        find.textContaining('Dashed is what was forecast'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('within about 2%'), findsOneWidget, reason: '(2.0 + 3.1 + 1.2) / 3');
      expect(find.text('Aug 1.52M / 1.49M'), findsOneWidget);
      expect(find.text('Oct 1.71M / 1.69M'), findsOneWidget);
      expect(
        find.text('Dashed is what was forecast on the 19th. Solid is what you actually spent.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^For the last 3 months, the forecast made on the 19th against what was'),
        ),
        findsOneWidget,
      );
      // The tallest of all six bars is October's forecast; the others scale to it.
      final oct = tester.getSize(find.byKey(const ValueKey('forecast-20261001'))).height;
      final sep = tester.getSize(find.byKey(const ValueKey('actual-20260901'))).height;
      final aug = tester.getSize(find.byKey(const ValueKey('forecast-20260801'))).height;
      expect(oct, AkSize.barChartSm);
      expect(sep, closeTo(AkSize.barChartSm * 1660000 / 1710000, 0.5));
      expect(aug, closeTo(AkSize.barChartSm * 1520000 / 1710000, 0.5));
      await expectLater(
        find.byType(ForecastScreen),
        matchesGoldenFile('goldens/forecast_history_light.png'),
      );
      semantics.dispose();
    });

    testWidgets('with Month starts on the 25th, How close still names the calendar date', (
      tester,
    ) async {
      final days = _tenDays();
      const history = [
        SnapshotPoint(periodStart: 20260925, dayInPeriod: 26, point: 1610000, actual: 1660000),
      ];
      await _pump(
        tester,
        const ForecastScreen(),
        calc: const PeriodCalculator(monthStartsOn: 25),
        data: _data(month: days, window: days, history: history),
      );
      await tester.dragUntilVisible(
        find.textContaining('Dashed is what was forecast'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.textContaining('forecast on the 19th.'), findsOneWidget);
    });

    testWidgets('a person with no saved forecast yet sees no history at all', (tester) async {
      final days = _tenDays();
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days),
      );
      expect(find.text('How close it has been'), findsNothing);
    });

    testWidgets("today's point pulses once, and not at all under reduced motion", (tester) async {
      double pulseAfterLoad() =>
          (tester
                      .widget<CustomPaint>(
                        find.descendant(
                          of: find.byType(CumulativeLineChart),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .painter!
                  as CumulativeLinePainter)
              .pulse!
              .value;

      final days = _tenDays();
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days),
      );
      // pumpAndSettle returned, so it did not loop; it ran to the end.
      expect(pulseAfterLoad(), 1);

      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days),
      );
      expect(pulseAfterLoad(), 0, reason: 'never started');
    });

    testWidgets('with "Forecast the month" off, the point shows without a range', (tester) async {
      final days = _tenDays();
      await _pump(
        tester,
        const ForecastScreen(),
        data: _data(month: days, window: days),
        settings: {SettingKeys.forecastMonth.name: '0'},
      );
      expect(find.textContaining('Likely'), findsNothing);
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

    testWidgets('the timeline says what is due on which day, from today to the month end', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [regularRow(id: 'r1', nextDueOn: 20261125)],
          extra: [regularRepoOverride(_MockRegularRepo())],
        ),
      );
      expect(find.text('A bigger circle is a bigger payment.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Timeline from 19 to 30 November. Data bundle UGX 10,000 on the 25th.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('regular payments golden, light', (tester) async {
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [
            regularRow(id: 'r1', nextDueOn: 20261121),
            regularRow(
              id: 'r2',
              label: 'Yaka electricity',
              typicalAmount: 30000,
              nextDueOn: 20261124,
              intervalDays: 30,
            ),
            regularRow(
              id: 'r3',
              label: 'Water bill',
              typicalAmount: 46000,
              nextDueOn: 20261126,
              intervalDays: 30,
            ),
          ],
          extra: [
            regularRepoOverride(_MockRegularRepo()),
            // Smart help's own reading reaches for the database; nothing looks regular here.
            looksRegularProvider.overrideWith((ref) => const []),
          ],
        ),
      );
      await expectLater(
        find.byType(RegularPaymentsScreen),
        matchesGoldenFile('goldens/regular_light.png'),
      );
    });

    testWidgets('Remind me the day before shows the stored choice', (tester) async {
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [regularRow(id: 'r1', nextDueOn: 20261125)],
          extra: [regularRepoOverride(_MockRegularRepo())],
        ),
        settings: {SettingKeys.regularReminder.name: '1'},
      );
      await tester.dragUntilVisible(
        find.text('Remind me the day before'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      final row = find.ancestor(
        of: find.text('Remind me the day before'),
        matching: find.byType(SettingsSwitchRow),
      );
      expect(tester.widget<SettingsSwitchRow>(row).value, isTrue);
    });

    testWidgets('a refused permission leaves the reminder off and says why', (tester) async {
      final fake = FakeNotifications(allow: false);
      await _pump(
        tester,
        const RegularPaymentsScreen(),
        data: _data(
          regular: [regularRow(id: 'r1', nextDueOn: 20261125)],
          extra: [
            regularRepoOverride(_MockRegularRepo()),
            notificationsServiceProvider.overrideWithValue(fake),
          ],
        ),
      );
      await tester.dragUntilVisible(
        find.text('Remind me the day before'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Remind me the day before'),
            matching: find.byType(SettingsSwitchRow),
          ),
          matching: find.byType(AkSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.asks, 1);
      expect(find.text(notificationsRefusedMessage), findsOneWidget);
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
