import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/onboarding/onboarding_providers.dart';
import 'package:akatabo/features/onboarding/onboarding_screen.dart';
import 'package:akatabo/features/onboarding/welcome_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Records settings writes instead of touching a database.
class _RecordingSettings extends SettingsRepository {
  _RecordingSettings() : super(AppDatabase(NativeDatabase.memory()));

  final writes = <String, Object?>{};

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async => writes[key.name] = value;
}

Future<_RecordingSettings> _pumpFirstLaunch(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  bool reduceMotion = false,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final settings = _RecordingSettings();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appearanceProvider.overrideWithValue(AkAppearance(themeMode: mode)),
        onboardingDoneProvider.overrideWithValue(false),
        settingsRepositoryProvider.overrideWithValue(settings),
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        appNowProvider.overrideWithValue(DateTime(2026, 11, 19, 9, 14)),
        latestRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        monthRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        allCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        spendingCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(const <Account>[])),
      ],
      child: const AkataboApp(),
    ),
  );
  if (reduceMotion) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return settings;
}

void main() {
  testWidgets('a first launch opens on Onboarding, not Home', (tester) async {
    await _pumpFirstLaunch(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Add it in seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('Next walks the three steps, then Welcome', (tester) async {
    await _pumpFirstLaunch(tester);
    for (final title in ['See where it went', 'Yours, on this phone']) {
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Skip, then "Look around first", lands on Home and remembers', (tester) async {
    final settings = await _pumpFirstLaunch(tester);
    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Know where your money goes.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Look around first'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('Three steps to get going'), findsOneWidget, reason: 'first-day Home');
    expect(settings.writes[SettingKeys.onboardingDone.name], isTrue);
  });

  testWidgets('"Add my first transaction" opens Add over Home', (tester) async {
    final settings = await _pumpFirstLaunch(tester);
    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add my first transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Save transaction'), findsOneWidget);
    expect(settings.writes[SettingKeys.onboardingDone.name], isTrue);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Three steps to get going'), findsOneWidget, reason: 'Home is underneath');
  });

  testWidgets('with reduced motion everything is in place on the first frame', (tester) async {
    await _pumpFirstLaunch(tester, reduceMotion: true);
    final opacities = tester.widgetList<Opacity>(
      find.descendant(of: find.byType(OnboardingScreen), matching: find.byType(Opacity)),
    );
    expect(opacities, isNotEmpty);
    expect(opacities.every((o) => o.opacity == 1), isTrue);
  });

  testWidgets('Onboarding and Welcome controls are labelled 44px targets', (tester) async {
    await _pumpFirstLaunch(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.bySemanticsLabel('Skip'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('onboarding and welcome goldens, ${mode.name}', (tester) async {
      await _pumpFirstLaunch(tester, mode: mode);
      await expectLater(
        find.byType(AkataboApp),
        matchesGoldenFile('goldens/onboarding_${mode.name}.png'),
      );
      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AkataboApp),
        matchesGoldenFile('goldens/welcome_${mode.name}.png'),
      );
    });
  }
}
