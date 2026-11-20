import 'package:akatabo/data/providers.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/services/backup/weekly_backup.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';

final _now = DateTime(2026, 11, 19, 9, 14);
int _ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  group('when the weekly backup is due', () {
    test('never while it is switched off', () {
      expect(weeklyBackupDue(enabled: false, lastAtMillis: 0, now: _now), isFalse);
    });

    test('at once when switched on with no backup yet', () {
      expect(weeklyBackupDue(enabled: true, lastAtMillis: 0, now: _now), isTrue);
    });

    test('seven days after the last backup, not before', () {
      final last = _now.subtract(const Duration(days: 7));
      expect(weeklyBackupDue(enabled: true, lastAtMillis: _ms(last), now: _now), isTrue);
      final recent = last.add(const Duration(minutes: 1));
      expect(weeklyBackupDue(enabled: true, lastAtMillis: _ms(recent), now: _now), isFalse);
    });

    test('when the clock was set back before the last backup', () {
      final future = _now.add(const Duration(days: 30));
      expect(weeklyBackupDue(enabled: true, lastAtMillis: _ms(future), now: _now), isTrue);
    });
  });

  group('the start-up check', () {
    late ProviderContainer container;
    late FakeBackupFiles files;
    var asked = 0;

    setUp(() {
      asked = 0;
      final db = memoryDb();
      files = FakeBackupFiles();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backupFilesProvider.overrideWithValue(files),
          backupServiceProvider.overrideWithValue(testBackupService(db)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
    });

    Future<void> setUpSettings({
      required bool weekly,
      required DateTime? last,
      bool protect = false,
    }) async {
      final s = container.read(settingsRepositoryProvider);
      await s.write(BackupKeys.weekly, weekly);
      await s.write(BackupKeys.protect, protect);
      if (last != null) await s.write(BackupKeys.lastAt, _ms(last));
    }

    Future<WeeklyOutcome> run() => withClock(
      Clock.fixed(_now),
      () => runWeeklyBackupAtStart(container, askForFolder: () async => asked++),
    );

    test('does nothing when not due', () async {
      await setUpSettings(weekly: true, last: _now.subtract(const Duration(days: 2)));
      expect(await run(), WeeklyOutcome.notDue);
      expect(asked, 0);
      expect(files.savedInto, isEmpty);
    });

    test('does nothing when switched off', () async {
      await setUpSettings(weekly: false, last: null);
      expect(await run(), WeeklyOutcome.notDue);
      expect(asked, 0);
    });

    test('asks for the folder again after a restart', () async {
      await setUpSettings(weekly: true, last: _now.subtract(const Duration(days: 8)));
      expect(await run(), WeeklyOutcome.needsFolder);
      expect(asked, 1);
    });

    test('writes to the folder picked in this run, and records the day', () async {
      await setUpSettings(weekly: true, last: _now.subtract(const Duration(days: 8)));
      final folder = FakeFolder();
      container.read(weeklyFolderProvider.notifier).set(folder);
      expect(await run(), WeeklyOutcome.saved);
      expect(asked, 0);
      expect(files.savedInto.single.folder, folder);
      expect(files.savedInto.single.name, 'akatabo-backup-2026-11-19.akatabo');
      expect(await container.read(settingsRepositoryProvider).read(BackupKeys.lastAt), _ms(_now));
    });

    test('a protected weekly backup asks, because the password is never kept', () async {
      await setUpSettings(weekly: true, last: null, protect: true);
      container.read(weeklyFolderProvider.notifier).set(FakeFolder());
      expect(await run(), WeeklyOutcome.needsFolder);
      expect(asked, 1);
      expect(files.savedInto, isEmpty);
    });

    test('asks once while the app runs: "Not now" holds when the app comes back', () async {
      await setUpSettings(weekly: true, last: null);
      final checks = WeeklyBackupChecks(container, ask: () async => asked++);
      Future<WeeklyOutcome?> check() => withClock(Clock.fixed(_now), checks.check);

      expect(await check(), WeeklyOutcome.needsFolder);
      expect(await check(), WeeklyOutcome.needsFolder, reason: 'still due');
      expect(asked, 1);
    });

    test('a folder that can no longer be used is reported, not thrown', () async {
      await setUpSettings(weekly: true, last: null);
      container.read(weeklyFolderProvider.notifier).set(FakeFolder());
      files.failSaveInto = true;
      expect(await run(), WeeklyOutcome.failed);
      expect(await container.read(settingsRepositoryProvider).read(BackupKeys.lastAt), 0);
    });
  });

  test('backup, lock and privacy keys stay on this phone; shared ones are restored', () {
    expect(isLocalOnlySetting(BackupKeys.lastAt.name), isTrue);
    expect(isLocalOnlySetting('lock.pinSet'), isTrue);
    expect(isLocalOnlySetting('general.monthStartsOn'), isFalse);
  });
}
