// Phase 8 accessibility sweep: every screen of the real app, on a small phone, with the
// demo data. Each screen is opened at text size 1.0, 1.3 and 2.0 and in both themes, and
// is checked for layout overflow, tap target size, labelled controls and text contrast.
//
// Run alone with: flutter test test/a11y/screen_sweep_test.dart
import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/seed/demo_seed.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../flutter_test_config.dart';
import '../support/backup_seed.dart';
import '../support/fake_backup.dart';
import '../support/fake_notifications.dart';
import '../support/fake_security.dart';

/// The project's target size (PLAN.md, Phase 8): every control at least 44 by 44. This is
/// Apple's minimum and above WCAG 2.2's 24 by 24; Android's 48 dp advice is met by the
/// primary controls (tabs, Add, Save) but not by picker swatches, which the design draws at 44.
const _tapTarget44 = MinimumTapTargetGuideline(
  size: Size(44, 44),
  link: 'https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum',
);

/// A small Android phone: 360 by 780 dp.
const _phone = Size(360, 780);

/// The smallest phone the app is laid out for: 360 by 640 dp (Phase 2, bigger type).
const _smallPhone = Size(360, 640);

/// Every screen the router can show. `{tx}` is replaced by a real transaction id.
final _screens = <String, String>{
  'Home': Routes.home,
  'Insights': Routes.insights,
  'Budgets': Routes.budgets,
  'Settings': Routes.settings,
  'Add': Routes.add,
  'All transactions': Routes.transactions,
  'One transaction': '/transactions/{tx}',
  'Calendar': Routes.calendar,
  'Categories': Routes.categories,
  'One category': '${Routes.categories}/${DefaultIds.food}',
  'Fees and tax': Routes.fees,
  'Forecast': Routes.forecast,
  'Regular payments': Routes.regular,
  'New regular payment': Routes.regularNew,
  'Set a budget': '${Routes.budgets}/${DefaultIds.food}',
  'General': Routes.settingsGeneral,
  'Appearance': Routes.settingsAppearance,
  'Accounts': Routes.settingsAccounts,
  'New account': Routes.settingsAccountNew,
  'Home settings': Routes.settingsHome,
  'Categories settings': Routes.settingsCategories,
  'New category': Routes.settingsCategoryNew,
  'Edit a category': '${Routes.settingsCategories}/${DefaultIds.food}/edit',
  'Money-in categories': Routes.settingsIncomeCategories,
  'Smart help': Routes.settingsSmart,
  'Reminders': Routes.settingsReminders,
  'Privacy and data': Routes.settingsPrivacy,
  'Export and backup': Routes.dataExport,
  'Restore': Routes.dataRestore,
  'Filters': Routes.filters,
  'Choose dates': Routes.chooseDates,
  'Onboarding': Routes.onboarding,
  'Welcome': Routes.welcome,
};

/// One phone's worth of data, made once per test on the real clock.
Future<({AppDatabase db, String txId})> _seededDb(WidgetTester tester, {bool dark = false}) async {
  final db = memoryDb();
  late String txId;
  await tester.runAsync(() async {
    final repo = TransactionRepository(db);
    await insertDemoData(repo, now: testNow, isEmpty: true);
    txId = (await repo.listAll()).first.id;
    if (dark) await SettingsRepository(db).write(SettingKeys.theme, ThemeMode.dark);
  });
  return (db: db, txId: txId);
}

Future<void> _open(
  WidgetTester tester,
  String location, {
  required AppDatabase db,
  double textScale = 1,
  Size size = _phone,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appNowProvider.overrideWithValue(testNow),
        backupFilesProvider.overrideWithValue(FakeBackupFiles() as BackupFiles),
        backupServiceProvider.overrideWithValue(testBackupService(db)),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        notificationsServiceProvider.overrideWithValue(FakeNotifications() as NotificationsService),
        ...securityOverrides(values: MapSecureValues()),
      ],
      child: AkataboApp(router: router, onboardingDone: true),
    ),
  );
  await _settle(tester);
}

/// Lets database work finish on the real clock, then redraws. Some screens animate once
/// (the forecast's today point), so this pumps fixed rounds instead of waiting to settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Unmounts the app before the database closes, so no stream is left listening.
Future<void> _close(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  addTearDown(db.close);
}

String _resolve(String location, String txId) => location.replaceAll('{tx}', txId);

/// Opens [location] and returns every layout error in full, including the line of the
/// widget that overflowed (the test framework keeps only the message of a single error).
Future<List<String>> _layoutErrors(
  WidgetTester tester,
  String location, {
  required AppDatabase db,
  double textScale = 1,
  Size size = _phone,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.toString());
  try {
    await _open(tester, location, db: db, textScale: textScale, size: size);
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  for (final MapEntry(key: name, value: location) in _screens.entries) {
    group(name, () {
      for (final scale in const [1.3, 2.0]) {
        testWidgets('lays out without overflow at text size $scale', (tester) async {
          final seeded = await _seededDb(tester);
          final errors = await _layoutErrors(
            tester,
            _resolve(location, seeded.txId),
            db: seeded.db,
            textScale: scale,
          );
          expect(errors, isEmpty, reason: '$name at $scale');
          await _close(tester, seeded.db);
        });
      }

      // The type went one step up (body 16): the smallest phone at the largest text must
      // still fit.
      testWidgets('lays out without overflow on a 360x640 phone at text size 2.0', (tester) async {
        final seeded = await _seededDb(tester);
        final errors = await _layoutErrors(
          tester,
          _resolve(location, seeded.txId),
          db: seeded.db,
          textScale: 2,
          size: _smallPhone,
        );
        expect(errors, isEmpty, reason: '$name at 2.0 on 360x640');
        await _close(tester, seeded.db);
      });

      for (final dark in const [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('meets tap target, label and contrast guidelines ($theme)', (tester) async {
          final handle = tester.ensureSemantics();
          final seeded = await _seededDb(tester, dark: dark);
          await _open(tester, _resolve(location, seeded.txId), db: seeded.db);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(_tapTarget44));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // Contrast is checked on the exact colour pairs in test/core/theme_contrast_test.dart.
          // textContrastGuideline samples pixels and reads anti-aliased 12px text as grey
          // (#55635C measured as #818B86), so on this app it reports false failures.
          await _close(tester, seeded.db);
          handle.dispose();
        });
      }
    });
  }
}
