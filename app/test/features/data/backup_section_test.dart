import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/features/data/backup_section.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';
import 'data_widgets_support.dart';

const _page = SettingsPage(title: 'Export and back up', children: [BackupSection()]);

void main() {
  late AppDatabase db;
  late FakeBackupFiles files;

  setUp(() {
    db = memoryDb();
    files = FakeBackupFiles();
  });
  tearDown(() => db.close());

  testWidgets('shows Back up everything as drawn', (tester) async {
    await pumpData(tester, _page, db: db, files: files);
    for (final text in [
      'BACK UP EVERYTHING',
      'One file holding every transaction, category, budget and setting. Keep it somewhere '
          'other than this phone, then restore it on any phone.',
      'Protect with a password',
      'Nobody can open the file without it',
      'Back up by itself every week',
      'To a folder you pick. Last backup: Never',
      'Save a backup file now',
      'Restore from a backup',
      'Bring your data back, or move to a new phone',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // Protected by default, as drawn.
    expect(tester.widget<AkSwitch>(switchLabelled('Protect with a password')).value, isTrue);
    expect(tester.widget<AkSwitch>(switchLabelled('Back up by itself every week')).value, isFalse);
  });

  testWidgets('Save a backup file now without a password saves and records the day', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await addEntry(db, DateTime(2026, 11, 18));
      await SettingsRepository(db).write(BackupKeys.protect, false);
    });
    await pumpData(tester, _page, db: db, files: files);
    await tester.tap(find.text('Save a backup file now'));
    await settle(tester);

    expect(files.saved, hasLength(1));
    expect(files.saved.single.name, endsWith('.akatabo'));
    final header = testBackupService(db).codec.readHeader(files.saved.single.bytes);
    expect(header.isProtected, isFalse);
    expect(header.counts['transactions'], 1);
    expect(
      await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.lastAt)),
      greaterThan(0),
    );
    expect(find.textContaining('Backup saved.'), findsOneWidget);
  });

  testWidgets('a protected backup asks for the password twice', (tester) async {
    await pumpData(tester, _page, db: db, files: files, size: const Size(390, 1200));
    await tester.tap(find.text('Save a backup file now'));
    await settle(tester);
    expect(find.text('Protect this backup'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'abc');
    await tester.tap(find.text('Use this password'));
    await tester.pump();
    expect(find.textContaining('Use at least 6'), findsOneWidget);

    await tester.enterText(fields.at(0), 'kampala-26');
    await tester.enterText(fields.at(1), 'kampala-62');
    await tester.tap(find.text('Use this password'));
    await tester.pump();
    expect(find.textContaining('not the same as the password above'), findsOneWidget);
    expect(files.saved, isEmpty);

    await tester.enterText(fields.at(1), 'kampala-26');
    await tester.tap(find.text('Use this password'));
    await settle(tester, rounds: 10);
    expect(files.saved, hasLength(1));
    final bytes = files.saved.single.bytes;
    final service = testBackupService(db);
    expect(service.codec.readHeader(bytes).isProtected, isTrue);
    final tables = await tester.runAsync(() => service.codec.decode(bytes, password: 'kampala-26'));
    expect(tables!['accounts'], isNotEmpty);
    final problem = await tester.runAsync(() async {
      try {
        await service.codec.decode(bytes, password: 'kampala-62');
        return null;
      } on BackupException catch (e) {
        return e.problem;
      }
    });
    expect(problem, BackupProblem.wrongPassword);
  });

  testWidgets('closing the password sheet saves nothing', (tester) async {
    await pumpData(tester, _page, db: db, files: files);
    await tester.tap(find.text('Save a backup file now'));
    await settle(tester);
    await tester.tapAt(const Offset(195, 20));
    await settle(tester);
    expect(files.saved, isEmpty);
  });

  group('Back up by itself every week', () {
    testWidgets('switching on picks a folder, backs up now and stays on', (tester) async {
      await tester.runAsync(() => SettingsRepository(db).write(BackupKeys.protect, false));
      files.folder = FakeFolder();
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(switchLabelled('Back up by itself every week'));
      await settle(tester);

      expect(files.savedInto, hasLength(1));
      expect(await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.weekly)), isTrue);
      expect(find.textContaining('Backed up to your folder'), findsOneWidget);
    });

    testWidgets('no folder picked: it stays off and says why', (tester) async {
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(switchLabelled('Back up by itself every week'));
      await settle(tester);

      expect(files.folderPicks, 1);
      expect(await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.weekly)), isFalse);
      expect(find.textContaining('No folder was picked'), findsOneWidget);
    });

    testWidgets('a folder picker that fails: it stays off and says the backup was not saved', (
      tester,
    ) async {
      files.failPickFolder = true;
      await pumpData(tester, _page, db: db, files: files);
      await tester.tap(switchLabelled('Back up by itself every week'));
      await settle(tester);

      expect(tester.takeException(), isStateError, reason: 'reported, not swallowed');
      expect(await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.weekly)), isFalse);
      expect(find.textContaining('The backup could not be saved'), findsOneWidget);
    });

    testWidgets('switching off saves off', (tester) async {
      await tester.runAsync(() => SettingsRepository(db).write(BackupKeys.weekly, true));
      await pumpData(tester, _page, db: db, files: files, settings: {BackupKeys.weekly.name: '1'});
      await tester.tap(switchLabelled('Back up by itself every week'));
      await settle(tester);
      expect(await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.weekly)), isFalse);
      expect(files.folderPicks, 0);
    });
  });

  testWidgets('Protect with a password saves its choice', (tester) async {
    await pumpData(tester, _page, db: db, files: files);
    await tester.tap(switchLabelled('Protect with a password'));
    await settle(tester);
    expect(await tester.runAsync(() => SettingsRepository(db).read(BackupKeys.protect)), isFalse);
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
        matchesGoldenFile('goldens/backup_section_${b.name}.png'),
      );
    });
  }
}
