import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/home/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        // The default calculator: "Month starts on" the 1st, weeks start on Sunday.
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        latestRowsProvider.overrideWith((ref) => Stream.value(latest)),
        monthRowsProvider.overrideWith((ref) => Stream.value(month)),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(previous)),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
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

void main() {
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

    testWidgets('home golden, ${b.name}', (tester) async {
      final (a, x, c, oct) = _filled();
      await _pumpHome(tester, latest: [a, x, c], month: [a, x, c], previous: [oct], brightness: b);
      await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home_${b.name}.png'));
    });
  }
}
