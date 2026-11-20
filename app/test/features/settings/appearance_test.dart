import 'dart:async';

import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/onboarding/onboarding_providers.dart';
import 'package:akatabo/features/settings/appearance_settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Settings kept in memory: a write updates the map and sends it down the stream the app
/// reads, the way the drift stream does on a phone, but under the test's control.
class _MemorySettings implements SettingsRepository {
  _MemorySettings([Map<String, String> start = const {}]) : values = {...start} {
    _changes.add(Map.of(values));
  }

  final Map<String, String> values;
  final _changes = StreamController<Map<String, String>>();

  Stream<Map<String, String>> get changes => _changes.stream;

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async {
    values[key.name] = key.encode(value);
    _changes.add(Map.of(values));
  }

  @override
  Stream<Map<String, String>> watchAll() => changes;

  Future<void> close() => _changes.close();

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _settingsOverrides(_MemorySettings settings) => [
  settingsRepositoryProvider.overrideWithValue(settings),
  storedSettingsProvider.overrideWith((ref) => settings.changes),
];

/// The real app, opened on Settings > Appearance, with only the data streams replaced.
Future<_MemorySettings> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 1100)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _MemorySettings({SettingKeys.theme.name: ThemeMode.light.name});
  addTearDown(settings.close);
  final router = buildRouter(initialLocation: Routes.settingsAppearance);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ..._settingsOverrides(settings),
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        appNowProvider.overrideWithValue(DateTime(2026, 11, 19, 9, 30)),
        onboardingDoneProvider.overrideWithValue(true),
        latestRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        monthRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        previousSameDaysRowsProvider.overrideWith((ref) => Stream.value(const <Transaction>[])),
        allCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(const <Account>[])),
      ],
      child: AkataboApp(router: router, onboardingDone: true),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

/// The colour, size and corner the running screen actually draws with.
Color? _backLinkColour(WidgetTester tester) =>
    tester.widget<Text>(find.text('Settings')).style?.color;
double? _labelSize(WidgetTester tester) => tester.widget<Text>(find.text('Theme')).style?.fontSize;
BorderRadiusGeometry? _chosenSegmentCorner(WidgetTester tester, String label) => tester
    .widget<Material>(find.ancestor(of: find.text(label), matching: find.byType(Material)).first)
    .borderRadius;
Color _screenGround(WidgetTester tester) =>
    Theme.of(tester.element(find.text('Appearance'))).scaffoldBackgroundColor;

void main() {
  testWidgets('changing Appearance rebuilds the running app at once, without a restart', (
    tester,
  ) async {
    final settings = await _pumpApp(tester);
    expect(find.text('Appearance'), findsOneWidget);
    expect(_screenGround(tester), akLightTokens.ground);
    expect(_backLinkColour(tester), akLightTokens.brandText);
    expect(_labelSize(tester), AkTextTokens.bodyMd.size);
    expect(_chosenSegmentCorner(tester, 'Light'), BorderRadius.circular(AkRadiusTokens.md));

    // Theme
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(settings.values[SettingKeys.theme.name], 'dark');
    expect(_screenGround(tester), akDarkTokens.ground);
    expect(tester.widget<Text>(find.text('Appearance')).style?.color, akDarkTokens.ink);
    expect(_backLinkColour(tester), akDarkTokens.brandText);

    // Main colour: the link, the chosen segment and the theme's primary all follow.
    await tester.tap(find.bySemanticsLabel('Plum'));
    await tester.pumpAndSettle();
    expect(settings.values[SettingKeys.mainColour.name], 'plum');
    final plum = paletteById('plum').dark;
    expect(_backLinkColour(tester), plum['brand-text']);
    expect(Theme.of(tester.element(find.text('Appearance'))).colorScheme.primary, plum['brand']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Plum')),
      isSemantics(label: 'Plum', isButton: true, isSelected: true),
    );

    // Back to light keeps the chosen colour, in its light form.
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(_backLinkColour(tester), paletteById('plum').light['brand-text']);

    // Corners
    await tester.tap(find.text('Square'));
    await tester.pumpAndSettle();
    expect(settings.values[SettingKeys.corners.name], 'square');
    expect(_chosenSegmentCorner(tester, 'Square'), BorderRadius.zero);

    // Text size
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(settings.values[SettingKeys.textSize.name], 'large');
    expect(_labelSize(tester), closeTo(AkTextTokens.bodyMd.size * 16 / 14, 1e-9));

    // Category chart is stored for the Categories screen.
    await tester.tap(find.text('Bars'));
    await tester.pumpAndSettle();
    expect(settings.values[SettingKeys.categoryChart.name], 'bars');
    expect(
      tester.getSemantics(find.text('Bars')),
      isSemantics(isSelected: true),
      reason: 'the page redraws with the new choice',
    );
  });

  group('Main colour swatches', () {
    Future<_MemorySettings> pumpScreen(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      double width = 390,
    }) async {
      tester.view
        ..physicalSize = Size(width, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = _MemorySettings();
      addTearDown(settings.close);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: _settingsOverrides(settings),
          child: MaterialApp(
            theme: buildAkTheme(brightness, const AkAppearance()),
            home: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return settings;
    }

    testWidgets('each colour is a named 44px button and Forest green starts chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      for (final p in akPalettes) {
        final swatch = find.byKey(ValueKey('swatch-${p.id}'));
        expect(swatch, findsOneWidget);
        final size = tester.getSize(swatch);
        expect(size.width, greaterThanOrEqualTo(AkSize.target), reason: p.label);
        expect(size.height, greaterThanOrEqualTo(AkSize.target), reason: p.label);
        expect(
          tester.getSemantics(find.bySemanticsLabel(p.label)),
          isSemantics(
            label: p.label,
            isButton: true,
            isSelected: p.id == 'green',
            isInMutuallyExclusiveGroup: true,
          ),
        );
      }
      await expectLater(
        tester,
        meetsGuideline(iOSTapTargetGuideline) /* the design's 44px target */,
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('tapping a colour saves it', (tester) async {
      final settings = await pumpScreen(tester);
      await tester.tap(find.byKey(const ValueKey('swatch-wine')));
      await tester.pumpAndSettle();
      expect(settings.values[SettingKeys.mainColour.name], 'wine');
    });

    double top(WidgetTester tester, String id) =>
        tester.getTopLeft(find.byKey(ValueKey('swatch-$id'))).dy;

    testWidgets('a 360 phone keeps all six colours on one row, each a 44px target', (tester) async {
      await pumpScreen(tester, width: 360);
      expect(tester.takeException(), isNull);
      expect(top(tester, 'wine'), top(tester, 'green'));
      for (final p in akPalettes) {
        expect(
          tester.getSize(find.byKey(ValueKey('swatch-${p.id}'))).width,
          greaterThanOrEqualTo(AkSize.target),
        );
      }
    });

    testWidgets('a narrower phone shows two even rows of three', (tester) async {
      await pumpScreen(tester, width: 320);
      expect(tester.takeException(), isNull);
      expect(top(tester, 'plum'), top(tester, 'green'));
      expect(top(tester, 'charcoal'), greaterThan(top(tester, 'green')));
      expect(top(tester, 'wine'), top(tester, 'charcoal'));
    });

    for (final b in Brightness.values) {
      testWidgets('appearance golden, ${b.name}', (tester) async {
        await pumpScreen(tester, brightness: b);
        await expectLater(
          find.byType(AppearanceSettingsScreen),
          matchesGoldenFile('goldens/appearance_${b.name}.png'),
        );
      });
    }
  });

  test('the app reads the stored main colour into its theme', () async {
    final settings = _MemorySettings({SettingKeys.mainColour.name: 'blue'});
    final container = ProviderContainer(overrides: _settingsOverrides(settings));
    addTearDown(() async {
      container.dispose();
      await settings.close();
    });
    container.listen(appearanceProvider, (_, _) {});
    await container.read(storedSettingsProvider.future);
    final look = container.read(appearanceProvider);
    expect(look.paletteId, 'blue');
    expect(
      buildAkTheme(Brightness.light, look).colorScheme.primary,
      paletteById('blue').light['brand'],
    );
  });
}
