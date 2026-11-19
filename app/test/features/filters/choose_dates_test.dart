import 'dart:async';

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/date_choice.dart';
import 'package:akatabo/features/filters/choose_dates_screen.dart';
import 'package:akatabo/features/filters/date_choice_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Thursday 19 November 2026, mid-morning, so "today" is fixed for every test.
final _now = DateTime(2026, 11, 19, 10);

// The period calculator reads the stored settings. A fixed, empty stream gives the defaults
// without opening the real database, which would leave timers pending in a test.
ProviderContainer _container({Stream<Map<String, String>>? settings}) => ProviderContainer(
  overrides: [
    appNowProvider.overrideWith((ref) => _now),
    storedSettingsProvider.overrideWith((ref) => settings ?? Stream.value(const {})),
  ],
);

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('date choice provider', () {
    test('starts with all dates, so the list is not narrowed by day', () {
      final c = _container();
      addTearDown(c.dispose);
      expect(c.read(dateChoiceProvider), isNull);
      expect(c.read(chosenPeriodProvider), isNull);
    });

    test('clear goes back to all dates', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(dateChoiceProvider.notifier).choosePreset(DatePreset.thisMonth);
      expect(c.read(chosenPeriodProvider), isNotNull);
      c.read(dateChoiceProvider.notifier).clear();
      expect(c.read(chosenPeriodProvider), isNull);
    });

    test('a preset is worked out from today', () {
      final c = _container();
      addTearDown(c.dispose);
      c.read(dateChoiceProvider.notifier).choosePreset(DatePreset.lastMonth);
      expect(c.read(dateChoiceProvider)?.preset, DatePreset.lastMonth);
      final period = c.read(chosenPeriodProvider)!;
      expect(period.start, DateTime(2026, 10));
      expect(period.lastDate, DateTime(2026, 10, 31));
    });

    test('a custom range keeps both days, the end included', () {
      final c = _container();
      addTearDown(c.dispose);
      c
          .read(dateChoiceProvider.notifier)
          .chooseCustom(DateTime(2026, 11, 5), DateTime(2026, 11, 19));
      expect(c.read(dateChoiceProvider)?.preset, DatePreset.custom);
      final period = c.read(chosenPeriodProvider)!;
      expect(period.start, DateTime(2026, 11, 5));
      expect(period.lastDate, DateTime(2026, 11, 19));
      expect(period.lengthInDays, 15);
    });

    test('a custom range ending before it starts is refused', () {
      final c = _container();
      addTearDown(c.dispose);
      expect(
        () => c
            .read(dateChoiceProvider.notifier)
            .chooseCustom(DateTime(2026, 11, 19), DateTime(2026, 11, 5)),
        throwsArgumentError,
      );
    });

    test('a settings change keeps the choice and redraws a preset from the new settings', () async {
      final settings = StreamController<Map<String, String>>();
      addTearDown(settings.close);
      final c = _container(settings: settings.stream);
      addTearDown(c.dispose);
      // As in bootstrap.dart, the settings stream is always listened to, so a provider with
      // no listener of its own (Riverpod pauses those) still sees the newest settings.
      c.listen(storedSettingsProvider, (_, _) {});
      c.listen(chosenPeriodProvider, (_, _) {});
      settings.add(const {});
      await _flush();

      // A custom range survives a save to "Month starts on".
      c
          .read(dateChoiceProvider.notifier)
          .chooseCustom(DateTime(2026, 11, 5), DateTime(2026, 11, 19));
      settings.add({SettingKeys.monthStartsOn.name: '25'});
      await _flush();
      expect(c.read(dateChoiceProvider)?.preset, DatePreset.custom);
      expect(c.read(chosenPeriodProvider)!.start, DateTime(2026, 11, 5));
      expect(c.read(chosenPeriodProvider)!.lastDate, DateTime(2026, 11, 19));

      // "This month" follows the setting: with months from the 25th, 19 November falls in
      // 25 October to 24 November.
      c.read(dateChoiceProvider.notifier).choosePreset(DatePreset.thisMonth);
      expect(c.read(chosenPeriodProvider)!.start, DateTime(2026, 10, 25));
      expect(c.read(chosenPeriodProvider)!.lastDate, DateTime(2026, 11, 24));
    });
  });

  group('Choose dates screen', () {
    Future<void> pumpScreen(WidgetTester tester, ProviderContainer container) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            home: const ChooseDatesScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('picks a custom range by tapping its first and last day', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpScreen(tester, container);

      // Opens on All dates, as the app starts; Custom starts from This month: 1 to 30 November.
      expect(find.text('Show all transactions'), findsOneWidget);

      await tester.tap(find.text('Custom'));
      await tester.pump();
      expect(find.text('Show these 30 days'), findsOneWidget);
      expect(find.text('From 1 Nov 2026'), findsOneWidget);
      expect(find.text('To 30 Nov 2026'), findsOneWidget);

      // The first tap starts a new range on Tuesday 10 November; the second sets its end.
      await tester.tap(find.bySemanticsLabel('Tuesday 10 November 2026'));
      await tester.pump();
      expect(find.text('From 10 Nov 2026'), findsOneWidget);
      expect(find.text('Show this day'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Sunday 15 November 2026'));
      await tester.pump();
      expect(find.text('To 15 Nov 2026'), findsOneWidget);
      expect(find.text('Show these 6 days'), findsOneWidget);

      await tester.tap(find.text('Show these 6 days'));
      await tester.pump();

      expect(container.read(dateChoiceProvider)?.preset, DatePreset.custom);
      final period = container.read(chosenPeriodProvider)!;
      expect(period.start, DateTime(2026, 11, 10));
      expect(period.lastDate, DateTime(2026, 11, 15));
    });

    testWidgets('a preset shows its own length and applies at once', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await pumpScreen(tester, container);

      await tester.tap(find.text('Last 7 days'));
      await tester.pump();
      expect(find.text('Show these 7 days'), findsOneWidget);

      await tester.tap(find.text('Show these 7 days'));
      await tester.pump();

      expect(container.read(dateChoiceProvider)?.preset, DatePreset.last7Days);
      final period = container.read(chosenPeriodProvider)!;
      expect(period.start, DateTime(2026, 11, 13));
      expect(period.lastDate, DateTime(2026, 11, 19));
    });

    testWidgets('All dates clears the range again', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      container
          .read(dateChoiceProvider.notifier)
          .chooseCustom(DateTime(2026, 11, 5), DateTime(2026, 11, 19));
      await pumpScreen(tester, container);

      await tester.tap(find.text('All dates'));
      await tester.pump();
      expect(find.text('Show all transactions'), findsOneWidget);

      await tester.tap(find.text('Show all transactions'));
      await tester.pump();
      expect(container.read(dateChoiceProvider), isNull);
      expect(container.read(chosenPeriodProvider), isNull);
    });

    testWidgets('opens on the range already chosen', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      container
          .read(dateChoiceProvider.notifier)
          .chooseCustom(DateTime(2026, 11, 5), DateTime(2026, 11, 19));
      await pumpScreen(tester, container);

      expect(find.text('From 5 Nov 2026'), findsOneWidget);
      expect(find.text('To 19 Nov 2026'), findsOneWidget);
      expect(find.text('Show these 15 days'), findsOneWidget);
    });
  });
}
