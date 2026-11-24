import 'package:akatabo/app/formats.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/settings/general_settings_screen.dart';
import 'package:akatabo/widgets/ak_pickers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

Future<AppDatabase> _pumpGeneral(
  WidgetTester tester, {
  Map<String, String> settings = const {},
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        // General names the account Add opens on; a live drift stream would not settle here.
        enabledAccountsProvider.overrideWith(
          (ref) =>
              Stream.value([accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)]),
        ),
      ],
      child: MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const GeneralSettingsScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return db;
}

Future<String?> _stored(WidgetTester tester, AppDatabase db, String key) =>
    tester.runAsync<String?>(
      () async => (await (db.select(
        db.settings,
      )..where((s) => s.key.equals(key))).getSingleOrNull())?.value,
    );

void main() {
  testWidgets('Month starts on opens a sheet with the current day ticked and in view', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpGeneral(tester, settings: {SettingKeys.monthStartsOn.name: '25'});
    await tester.tap(find.text('The 25th'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('up to the 28th'), findsOneWidget);
    final row = find.bySemanticsLabel('The 25th').last;
    expect(
      tester.getSemantics(row),
      isSemantics(isButton: true, isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    // Scrolled into view without the person scrolling.
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.contains(tester.getCenter(row)), isTrue);
    handle.dispose();
  });

  testWidgets('choosing a week start in the sheet saves it and closes the sheet', (tester) async {
    final db = await _pumpGeneral(tester);
    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

    expect(find.byType(BottomSheet), findsNothing);
    expect(await _stored(tester, db, SettingKeys.weekStartsOn.name), '${DateTime.monday}');
  });

  testWidgets('Date style shows the style as a date, and a new choice is saved', (tester) async {
    final db = await _pumpGeneral(tester);
    await tester.tap(find.text('19 Nov 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-11-19'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(await _stored(tester, db, SettingKeys.dateStyle.name), DateStyle.yearFirst.name);
  });

  testWidgets('How amounts are written saves the short form', (tester) async {
    final db = await _pumpGeneral(tester);
    await tester.tap(find.text('1.28M'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(await _stored(tester, db, SettingKeys.amountStyle.name), AmountStyle.short.name);
  });

  testWidgets('dismissing the sheet saves nothing', (tester) async {
    final db = await _pumpGeneral(tester);
    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 40)); // the dimmed area above the sheet
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

    expect(find.byType(BottomSheet), findsNothing);
    expect(await _stored(tester, db, SettingKeys.weekStartsOn.name), isNull);
  });

  testWidgets('Language is a plain row that says why it cannot change', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpGeneral(tester);
    expect(find.text('UGX only'), findsOneWidget, reason: 'Currencies and rates shows its value');
    expect(
      tester.getSemantics(find.text('English')),
      isSemantics(hasTapAction: false, isButton: false),
    );
    expect(find.textContaining('cannot be changed'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    handle.dispose();
  });

  testWidgets('the choice sheet works on its own and in the dark theme', (tester) async {
    int? picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkTheme(Brightness.dark, const AkAppearance()),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => picked = await showAkChoiceSheet<int>(
                context,
                title: 'Pick one',
                options: const [(1, 'One'), (2, 'Two')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pick one'), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('Two')).height,
      greaterThanOrEqualTo(AkSize.target),
    );
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(picked, 2);
  });
}
