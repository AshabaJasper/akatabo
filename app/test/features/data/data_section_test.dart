import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/features/data/backup_actions.dart';
import 'package:akatabo/features/data/data_section.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/services/security/lock_controller.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';
import '../../support/fake_security.dart';
import 'data_widgets_support.dart';

const _page = SettingsPage(title: 'Privacy and data', children: [DataSection()]);

Future<int> _entries(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.transactions).get()))!.length;

void main() {
  late AppDatabase db;
  late FakeBackupFiles files;

  setUp(() {
    db = memoryDb();
    files = FakeBackupFiles();
  });
  tearDown(() => db.close());

  testWidgets('shows the drawn rows, with the last backup day or Never', (tester) async {
    await pumpData(tester, _page, db: db, files: files);
    for (final text in [
      'DATA AND BACKUP',
      'Export and back up',
      'CSV, Excel, PDF, backup file',
      'Export a monthly report',
      'PDF',
      'Save a backup file now',
      'Last: Never',
      'Back up every week',
      'To a folder you choose on this phone',
      'Restore from a backup file',
      'Delete everything on this phone',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('shows the last backup day and the weekly switch from settings', (tester) async {
    await pumpData(
      tester,
      _page,
      db: db,
      files: files,
      settings: {
        BackupKeys.lastAt.name: '${DateTime(2026, 11, 12, 20).millisecondsSinceEpoch}',
        BackupKeys.weekly.name: '1',
      },
    );
    expect(find.text('Last: 12 Nov 2026'), findsOneWidget);
    expect(tester.widget<AkSwitch>(switchLabelled('Back up every week')).value, isTrue);
  });

  group('Delete everything on this phone', () {
    testWidgets('asks first, says it cannot be undone, and Cancel keeps everything', (
      tester,
    ) async {
      await tester.runAsync(() => addEntry(db, DateTime(2026, 11, 18)));
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();

      expect(find.text('Delete everything on this phone?'), findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
      expect(find.textContaining('Save a backup file first'), findsOneWidget);
      expect(find.text('Save a backup first'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await _entries(tester, db), 1);
    });

    testWidgets('Delete everything wipes the phone back to its first day', (tester) async {
      await tester.runAsync(() async {
        await addEntry(db, DateTime(2026, 11, 18));
        await SettingsRepository(db).write(BackupKeys.lastAt, 5);
      });
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await settle(tester);

      expect(await _entries(tester, db), 0);
      final accounts = await tester.runAsync(() => db.select(db.accounts).get());
      expect(accounts, isNotEmpty, reason: 'the starting accounts are back');
      expect(find.text('Everything on this phone was deleted.'), findsOneWidget);
    });

    testWidgets('Delete everything also removes the PIN and the lock setting', (tester) async {
      final secure = (await tester.runAsync(() => valuesWithPin('2580')))!;
      await tester.runAsync(() => SettingsRepository(db).write(PrivacyKeys.lockOn, true));
      expect(secure.values, isNotEmpty);
      await pumpData(tester, _page, db: db, files: files, secure: secure);
      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await settle(tester);

      expect(secure.values, isEmpty, reason: 'no PIN is left in secure storage');
      final lockOn = await tester.runAsync(() => SettingsRepository(db).read(PrivacyKeys.lockOn));
      expect(lockOn, isFalse);
    });

    testWidgets('"Save a backup first" saves a file and deletes nothing', (tester) async {
      await tester.runAsync(() async {
        await addEntry(db, DateTime(2026, 11, 18));
        await SettingsRepository(db).write(BackupKeys.protect, false);
      });
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(find.text('Delete everything on this phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save a backup first'));
      await settle(tester);

      expect(files.saved, hasLength(1));
      expect(await _entries(tester, db), 1);
    });
  });

  testWidgets('the save dialog hiding the app does not lock it, even "Right away"', (tester) async {
    final secure = (await tester.runAsync(() => valuesWithPin('2580')))!;
    await tester.runAsync(() => SettingsRepository(db).write(BackupKeys.protect, false));
    await pumpData(
      tester,
      _page,
      db: db,
      files: files,
      secure: secure,
      settings: {
        PrivacyKeys.lockOn.name: PrivacyKeys.lockOn.encode(true),
        PrivacyKeys.lockAfter.name: PrivacyKeys.lockAfter.encode(LockAfter.rightAway),
      },
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(DataSection)));
    final lock = container.read(lockControllerProvider.notifier);
    await tester.runAsync(() => lock.unlockWithPin('2580'));
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
    files.whileSaving = () {
      lock.wentAway();
      lock.cameBack();
    };

    await tester.tap(find.text('Save a backup file now'));
    await settle(tester);

    expect(files.saved, hasLength(1));
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
  });

  testWidgets('leaving the screen while protection is read saves nothing unprotected', (
    tester,
  ) async {
    await tester.runAsync(() => SettingsRepository(db).write(BackupKeys.protect, true));
    late WidgetRef ref;
    late BuildContext gone;
    final show = ValueNotifier(true);
    await pumpData(
      tester,
      Consumer(
        builder: (_, r, _) {
          ref = r;
          return ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, on, _) => on
                ? Builder(
                    builder: (c) {
                      gone = c;
                      return const SizedBox();
                    },
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
      db: db,
      files: files,
    );
    // The screen that asked closes before the password could be asked for.
    show.value = false;
    await tester.pump();
    expect(gone.mounted, isFalse);

    final message = await tester.runAsync(() => BackupActions(ref).saveNow(gone));
    expect(message, isNull);
    expect(files.saved, isEmpty);
  });

  for (final b in Brightness.values) {
    testWidgets('golden, ${b.name}', (tester) async {
      await pumpData(
        tester,
        _page,
        db: db,
        files: files,
        brightness: b,
        settings: {BackupKeys.lastAt.name: '${DateTime(2026, 11, 12, 20).millisecondsSinceEpoch}'},
      );
      await expectLater(
        find.byType(SettingsPage),
        matchesGoldenFile('goldens/data_section_${b.name}.png'),
      );
    });
  }
}
