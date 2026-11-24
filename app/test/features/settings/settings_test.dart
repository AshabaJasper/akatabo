import 'package:akatabo/core/icons/ak_icon.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/privacy/about_section.dart';
import 'package:akatabo/features/settings/appearance_settings_screen.dart';
import 'package:akatabo/features/settings/categories_settings_screen.dart';
import 'package:akatabo/features/settings/general_settings_screen.dart';
import 'package:akatabo/features/settings/home_layout.dart';
import 'package:akatabo/features/settings/settings_screen.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:akatabo/widgets/ak_surfaces.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

/// Polls until [condition] holds, so a stored value has time to reach the providers.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final _accounts = [accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)];

Future<void> _pump(WidgetTester tester, Widget screen, AppDatabase db) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // A fixed, empty settings stream: the pages show their defaults. The saved value is
        // checked in the database instead, because a live drift stream does not settle here.
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        // General names the account Add opens on; a live drift stream would not settle here.
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
      ],
      child: MaterialApp(theme: buildAkTheme(Brightness.light, const AkAppearance()), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets a database write finish on the real clock, then redraws the frames it caused.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<String?> _stored(WidgetTester tester, AppDatabase db, String key) =>
    tester.runAsync<String?>(
      () async => (await (db.select(
        db.settings,
      )..where((s) => s.key.equals(key))).getSingleOrNull())?.value,
    );

void main() {
  group('a saved setting changes the app', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      container.listen(periodCalculatorProvider, (_, _) {});
      container.listen(storedAppearanceProvider, (_, _) {});
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('a month that starts on the 25th changes the periods the app reads', () async {
      expect(container.read(periodCalculatorProvider).monthStartsOn, 1);
      await container.read(settingsRepositoryProvider).write(SettingKeys.monthStartsOn, 25);
      await _until(() => container.read(periodCalculatorProvider).monthStartsOn == 25);
      expect(container.read(periodCalculatorProvider).monthStartsOn, 25);
    });

    test('the theme, text size and corners are read back and rebuild the theme', () async {
      final repo = container.read(settingsRepositoryProvider);
      await repo.write(SettingKeys.theme, ThemeMode.dark);
      await repo.write(SettingKeys.textSize, AkTextSize.large);
      await repo.write(SettingKeys.corners, AkCorners.square);
      await _until(() {
        final look = container.read(storedAppearanceProvider);
        return look.themeMode == ThemeMode.dark &&
            look.textSize == AkTextSize.large &&
            look.corners == AkCorners.square;
      });

      final look = container.read(storedAppearanceProvider);
      expect(look.themeMode, ThemeMode.dark);
      expect(look.textSize, AkTextSize.large);
      expect(look.corners, AkCorners.square);
      expect(buildAkTheme(Brightness.dark, look).brightness, Brightness.dark);
    });

    test('a damaged stored value falls back to the default', () async {
      await container.read(settingsRepositoryProvider).write(SettingKeys.monthStartsOn, 25);
      await _until(() => container.read(periodCalculatorProvider).monthStartsOn == 25);
      // 31 is outside the 1st to 28th, so it is read as the default.
      expect(SettingKeys.monthStartsOn.decode('31'), 1);
      expect(SettingKeys.monthStartsOn.decode('abc'), 1);
    });
  });

  group('the Settings pages', () {
    testWidgets('the hub lists each page with what it holds', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const SettingsScreen(), db);
      expect(find.text('Settings'), findsOneWidget);
      for (final title in [
        'General',
        'Accounts',
        'Categories',
        'Appearance',
        'Home screen',
        'Smart help',
        'Reminders',
        'App lock',
        'Privacy and security',
        'Data and backup',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Cash, MTN MoMo, Airtel Money, bank'), findsOneWidget);
    });

    testWidgets('the hub is three cards, each row with a tile and a chevron, and a footer', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const SettingsScreen(), db);
      // Three groups: 3 + 4 + 4 pages, App lock and Phone permissions each with a row.
      expect(find.byType(AkCard), findsNWidgets(3));
      expect(find.byType(AkIconTile), findsNWidgets(11));
      expect(find.byType(AkIcon), findsNWidgets(22), reason: 'a tile icon and a chevron per row');
      // The version cannot be read in a test, so the footer is the plain line. It sits below
      // the search field and three cards, past the bottom of the test screen.
      await tester.scrollUntilVisible(
        find.text('Free, with no account and no adverts.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Free, with no account and no adverts.'), findsOneWidget);
      // Text sits inside the card, not against its edge.
      final card = tester.getTopLeft(find.byType(AkCard).first);
      final title = tester.getTopLeft(find.text('General'));
      expect(title.dx - card.dx, greaterThan(AkSpace.s3));
    });

    testWidgets('in dark, tile icons use brand-text, not brand-deep, so they can be seen', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.dark, const AkAppearance()),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final tile = find.byType(AkIconTile).first;
      final colours = tester.element(tile).colors;
      expect(colours.brandText, isNot(colours.brandDeep), reason: 'dark tokens differ');
      final icon = tester.widget<AkIcon>(find.descendant(of: tile, matching: find.byType(AkIcon)));
      expect(icon.color, colours.brandText);
    });

    testWidgets('the footer names the version once it is known', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
          ],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      const footer = 'Akatabo 1.0.0 (1). Free, with no account and no adverts.';
      await tester.scrollUntilVisible(
        find.text(footer),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(footer), findsOneWidget);
    });

    testWidgets('General shows the defaults until something is chosen', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const GeneralSettingsScreen(), db);
      expect(find.text('The 1st'), findsOneWidget, reason: 'month starts on the 1st');
      expect(find.text('Sunday'), findsOneWidget, reason: 'week starts on Sunday');
      expect(find.text('UGX, Ugandan shilling'), findsOneWidget);
    });

    testWidgets('a long value wraps instead of overflowing at large text', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
            enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
          ],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const GeneralSettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('UGX, Ugandan shilling'), findsOneWidget);
    });

    testWidgets('choosing a month start saves it and shows it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const GeneralSettingsScreen(), db);

      await tester.tap(find.text('The 1st'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(); // the choice sheet slides up from below the screen
      // The list of 28 days is taller than the test screen, so scroll to the day first.
      await tester.ensureVisible(find.text('The 25th'));
      await tester.tap(find.text('The 25th'));
      await _settle(tester);

      expect(await _stored(tester, db, SettingKeys.monthStartsOn.name), '25');
      // The row redraws from the live settings stream, which these widget tests replace with a
      // fixed one; the screen reading the saved value is covered by the provider tests.
    });

    testWidgets('choosing money in as the new entry saves it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const GeneralSettingsScreen(), db);

      await tester.tap(find.text('Money in'));
      await _settle(tester);

      expect(await _stored(tester, db, SettingKeys.newEntryDirection.name), 'moneyIn');
    });

    testWidgets('Appearance offers the three themes and saves the one chosen', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, const AppearanceSettingsScreen(), db);

      expect(find.text('Follow phone'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.text('Rounded'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.theme.name), 'dark');
    });
  });

  group('accounts and Home', () {
    test('switching an account off removes it from the accounts offered on Add', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = AccountRepository(db);
      expect((await repo.watchEnabled().first).any((a) => a.id == DefaultIds.mtn), isTrue);

      await repo.setEnabled(DefaultIds.mtn, enabled: false);
      expect((await repo.watchEnabled().first).any((a) => a.id == DefaultIds.mtn), isFalse);

      await repo.setEnabled(DefaultIds.mtn, enabled: true);
      expect((await repo.watchEnabled().first).any((a) => a.id == DefaultIds.mtn), isTrue);
    });

    test('the Home layout reads each section switch from storage', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      container.listen(homeLayoutProvider, (_, _) {});
      await container
          .read(settingsRepositoryProvider)
          .write(SettingKeys.homeShowWhereItWent, false);
      await _until(() => !container.read(homeLayoutProvider).whereItWent);
      final layout = container.read(homeLayoutProvider);
      expect(layout.whereItWent, isFalse);
      expect(layout.latest, isTrue, reason: 'the other sections keep their default');
      expect(layout.headerTiles, isTrue);
    });
  });

  group('new account', () {
    test('a new account is saved with its kind and colour, and an empty name is refused', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = AccountRepository(db);

      await repo.add(name: '  Airtel wallet  ', kind: AccountKind.airtel);
      final all = await repo.watchAll().first;
      final added = all.singleWhere((a) => a.name == 'Airtel wallet');
      expect(added.kind, AccountKind.airtel);
      expect(added.colourToken, 'acct-airtel');
      expect(added.enabled, isTrue);

      await expectLater(repo.add(name: '   ', kind: AccountKind.bank), throwsArgumentError);
    });
    // The New account form itself is tested in new_account_test.dart.
  });

  group('categories', () {
    test('a hidden category leaves the spending list that Add reads', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CategoryRepository(db);
      expect(
        (await repo.watch(CategoryKind.spending).first).any((c) => c.id == DefaultIds.food),
        isTrue,
      );

      await repo.setHidden(DefaultIds.food, hidden: true);
      expect(
        (await repo.watch(CategoryKind.spending).first).any((c) => c.id == DefaultIds.food),
        isFalse,
      );

      await repo.setHidden(DefaultIds.food, hidden: false);
      expect(
        (await repo.watch(CategoryKind.spending).first).any((c) => c.id == DefaultIds.food),
        isTrue,
      );
    });

    testWidgets('switching a category off saves it, and fees and tax are not listed', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
            allCategoriesProvider.overrideWith(
              (ref) => Stream.value([
                categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
                categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            home: const CategoriesSettingsScreen(),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Food and shopping'), findsOneWidget);
      expect(find.text('Fees and tax'), findsNothing);

      await tester.tap(find.byType(AkSwitch));
      await _settle(tester);
      final hidden = await tester.runAsync(
        () async => (await (db.select(
          db.categories,
        )..where((c) => c.id.equals(DefaultIds.food))).getSingle()).hidden,
      );
      expect(hidden, isTrue);
    });
  });

  group('rename a category', () {
    test('a category is renamed, trimmed, and an empty name is refused', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CategoryRepository(db);

      await repo.rename(DefaultIds.food, name: '  Groceries  ');
      final row = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(DefaultIds.food))).getSingle();
      expect(row.name, 'Groceries');

      await expectLater(repo.rename(DefaultIds.food, name: '  '), throwsArgumentError);
    });
  });
}
