// The whole app on a real Android device or emulator: unlock with the PIN, first launch,
// three entries, a budget, a backup, delete everything, then restore that backup.
//
// Run on the emulator or a phone: flutter test integration_test -d <device id>
//
// The database is in memory and the file dialogs are faked, so nothing is left on the
// device and no system dialog needs a tap. Everything else is the real app.
import 'dart:async';

import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/support/backup_seed.dart';
import '../test/support/fake_backup.dart';
import '../test/support/fake_notifications.dart';
import '../test/support/fake_security.dart';

/// Lets the database and animations catch up. Fixed rounds, since the forecast's today
/// point animates once and pumpAndSettle would wait on it.
Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// A long screen builds only the rows in view, so a button further down is not there to find
/// until the list scrolls to it, as a person would. Drags the screen's main list until
/// [finder] is built, or until it cannot move further.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final lists = find.byType(ListView);
  if (lists.evaluate().isEmpty) return;
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(lists.last, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  if (finder.evaluate().isEmpty) {
    final shown = [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        t.data ?? t.textSpan?.toPlainText(),
    ];
    fail('Not on screen: $finder\nShown: $shown');
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<int> _entries(AppDatabase db) async => (await db.select(db.transactions).get()).length;

Future<void> _addEntry(WidgetTester tester, String amount, String words, String category) async {
  await _tap(tester, find.bySemanticsLabel('Add a transaction').last);
  await tester.enterText(find.byType(TextField).at(0), amount);
  await tester.enterText(find.byType(TextField).at(1), words);
  await tester.pump();
  await _tap(tester, find.bySemanticsLabel(category).last);
  await _tap(tester, find.text('Save transaction'));
  expect(find.text('Save transaction'), findsNothing, reason: 'Add closed after saving $words');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unlock, start, add, budget, back up, delete everything, restore', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = memoryDb();
    await SettingsRepository(db).write(PrivacyKeys.lockOn, true);
    // Protection is on by default; this journey's backup has no password. The password path
    // is covered by the widget tests and the backup round-trip tests.
    await SettingsRepository(db).write(BackupKeys.protect, false);
    final files = FakeBackupFiles();
    // A first launch opens on Onboarding, as main.dart does when onboarding is not done.
    final router = buildRouter(initialLocation: Routes.onboarding);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backupFilesProvider.overrideWithValue(files as BackupFiles),
          backupServiceProvider.overrideWithValue(testBackupService(db)),
          notificationsServiceProvider.overrideWithValue(
            FakeNotifications() as NotificationsService,
          ),
          ...securityOverrides(values: await valuesWithPin('2580')),
        ],
        child: AkataboApp(router: router, onboardingDone: false),
      ),
    );
    await _settle(tester);

    // 1. The lock screen comes first. A wrong PIN is refused; the right one opens the app.
    for (final d in ['1', '1', '1', '1']) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await _settle(tester);
    expect(find.bySemanticsLabel('2').last, findsOneWidget, reason: 'still locked');
    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.bySemanticsLabel(d).last);
      await tester.pump();
    }
    await _settle(tester, rounds: 20);

    // 2. First launch: skip the tour and look around.
    await _tap(tester, find.bySemanticsLabel('Skip'));
    await _tap(tester, find.bySemanticsLabel('Look around first'));

    // 3. Three entries through the real Add screen.
    await _addEntry(tester, '12000', 'Lunch at Javas', 'Food and shopping');
    await _addEntry(tester, '5000', 'Boda to town', 'Transport');
    await _addEntry(tester, '30000', 'Yaka electricity', 'Bills');
    expect(await _entries(db), 3);

    // 4. A budget for food.
    unawaited(router.push('${Routes.budgets}/${DefaultIds.food}'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '300000');
    await _tap(tester, find.text('Save budget'));
    final food = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(DefaultIds.food))).getSingle();
    expect(food.monthlyBudget, 300000);

    // 5. Back up, with no password.
    router.go(Routes.settingsPrivacy);
    await _settle(tester);
    await _tap(tester, find.text('Save a backup file now'));
    await _settle(tester, rounds: 20);
    expect(files.saved, hasLength(1));
    final backup = files.saved.single;

    // 6. Delete everything: the phone is back to its first day.
    await _tap(tester, find.text('Delete everything on this phone'));
    await _tap(tester, find.text('Delete everything'));
    await _settle(tester, rounds: 20);
    expect(await _entries(db), 0);

    // 7. Restore the backup and get all three entries and the budget back.
    files.toPick = (name: backup.name, bytes: backup.bytes);
    router.go(Routes.dataRestore);
    await _settle(tester);
    await _tap(tester, find.text('Choose a backup file'));
    await _settle(tester, rounds: 20);
    await _tap(tester, find.text('Restore 3 transactions'));
    await _settle(tester, rounds: 30);
    expect(find.text('Restore finished'), findsOneWidget);
    expect(await _entries(db), 3);
    final restored = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(DefaultIds.food))).getSingle();
    expect(restored.monthlyBudget, 300000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
    semantics.dispose();
  });
}
