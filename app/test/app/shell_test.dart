import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/budgets/budgets_providers.dart';
import 'package:akatabo/features/goals/goals_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/home/home_screen.dart';
import 'package:akatabo/features/insights/insights_screen.dart';
import 'package:akatabo/features/onboarding/onboarding_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  bool? onboardingDone,
  bool settingsSay = true,
  Map<String, String> stored = const {},
  AppOpensOn? opensOn,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(stored)),
        goalsProvider.overrideWith((ref) => Stream.value(const <Goal>[])),
        allGoalMovesProvider.overrideWith((ref) => Stream.value(const <GoalMove>[])),
        appearanceProvider.overrideWithValue(AkAppearance(themeMode: mode)),
        // Home reads the database; the shell test uses an empty, fixed Home instead.
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        // A fixed day, and no midnight timer left pending when the test ends.
        appNowProvider.overrideWithValue(DateTime(2026, 11, 19, 9, 30)),
        // A returning person: the shell, not Onboarding.
        onboardingDoneProvider.overrideWithValue(settingsSay),
        latestRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        monthRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        previousMonthRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        allCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(const <Account>[])),
      ],
      child: AkataboApp(onboardingDone: onboardingDone, opensOn: opensOn),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on Home with five navigation targets', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Home'), findsWidgets);
    for (final label in ['Home', 'Insights', 'Add a transaction', 'Goals', 'Settings']) {
      expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
    }
  });

  testWidgets('"The app opens on: Insights" starts on Insights', (tester) async {
    await _pumpApp(tester, opensOn: AppOpensOn.insights);
    expect(find.byType(InsightsScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('"The app opens on: Add" starts on Add, with Home underneath it', (tester) async {
    // As main.dart passes it: read from the database before the settings stream has loaded.
    await _pumpApp(tester, opensOn: AppOpensOn.add);
    expect(find.text('Save transaction'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Save transaction'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a first launch opens on Onboarding whatever "The app opens on" says', (
    tester,
  ) async {
    await _pumpApp(tester, onboardingDone: false, settingsSay: false, opensOn: AppOpensOn.add);
    expect(find.text('Save transaction'), findsNothing);
  });

  testWidgets('the stored flag wins when settings have not loaded in time', (tester) async {
    // Settings timed out, so the provider says "not done"; the flag read at start says done.
    await _pumpApp(tester, onboardingDone: true, settingsSay: false);
    expect(find.bySemanticsLabel('Add a transaction'), findsWidgets, reason: 'the shell');
    expect(find.text('Add it in seconds'), findsNothing, reason: 'not Onboarding');
  });

  testWidgets('each tab opens its screen', (tester) async {
    await _pumpApp(tester);
    for (final tab in ['Insights', 'Goals', 'Settings', 'Home']) {
      await tester.tap(find.bySemanticsLabel(tab).last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Scaffold, tab), findsWidgets, reason: tab);
    }
  });

  testWidgets('Add covers the tabs and closing it returns to where the person was', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Insights').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add a transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Save transaction'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Save transaction'), findsNothing);
    expect(find.widgetWithText(Scaffold, 'Insights'), findsWidgets);
  });

  // The design system's floor is 44px (Apple's 44pt, WCAG 2.5.5). Android's own check asks
  // for 48dp; the drawn 44px month pill on Home is held to the design's floor instead.
  testWidgets('every navigation target is at least 44px', (tester) async {
    await _pumpApp(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('shell golden, ${mode.name}', (tester) async {
      await _pumpApp(tester, mode: mode);
      await expectLater(
        find.byType(AkataboApp),
        matchesGoldenFile('goldens/shell_${mode.name}.png'),
      );
    });
  }
}
