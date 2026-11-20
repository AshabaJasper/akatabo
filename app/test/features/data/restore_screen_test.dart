import 'dart:convert';
import 'dart:typed_data';

import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/features/data/restore_parts.dart';
import 'package:akatabo/features/data/restore_screen.dart';
import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';
import 'data_widgets_support.dart';

/// A backup of a phone with entries from 1 March to 12 November.
Future<Uint8List> _backupBytes(WidgetTester tester, {String? password}) async =>
    (await tester.runAsync(() async {
      final source = memoryDb();
      await seedFullPhone(source);
      final bytes = await withClock(
        Clock.fixed(DateTime(2026, 11, 19, 9, 14)),
        () => testBackupService(source).createFile(password: password),
      );
      await source.close();
      return bytes;
    }))!;

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

  Future<void> pumpRestore(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool fromPrivacy = false,
  }) => pumpData(
    tester,
    RestoreScreen(fromPrivacy: fromPrivacy),
    db: db,
    files: files,
    brightness: brightness,
  );

  Future<void> choose(
    WidgetTester tester,
    Uint8List bytes, {
    String name = 'akatabo-backup-2026-11-12.akatabo',
  }) async {
    files.toPick = (name: name, bytes: bytes);
    await tester.tap(find.text('Choose a backup file'));
    await settle(tester, rounds: 10);
  }

  /// This phone: two entries the backup does not have, on 13 and 19 November.
  Future<void> phoneEntries(WidgetTester tester) => tester.runAsync(() async {
    await addEntry(db, DateTime(2026, 11, 13), description: 'Boda');
    await addEntry(db, DateTime(2026, 11, 19), description: 'Airtime');
  });

  testWidgets('step 1 says what happens and offers the file dialog', (tester) async {
    await pumpRestore(tester);
    expect(find.text('Export and back up'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Step 1 of 3: Choose file')), findsOneWidget);
    expect(find.textContaining('Its name ends in .akatabo'), findsOneWidget);
    expect(find.textContaining('before anything on this phone changes'), findsOneWidget);
    expect(find.text('Choose a backup file'), findsOneWidget);
  });

  testWidgets('opened from Privacy and data, the back link says so', (tester) async {
    await pumpRestore(tester, fromPrivacy: true);
    expect(find.text('Privacy and data'), findsOneWidget);
  });

  testWidgets('cancelling the file dialog leaves step 1', (tester) async {
    await pumpRestore(tester);
    await tester.tap(find.text('Choose a backup file'));
    await settle(tester);
    expect(files.picks, 1);
    expect(find.text('Choose a backup file'), findsOneWidget);
  });

  testWidgets('step 2 shows what is in the backup with real counts, then adds what is missing', (
    tester,
  ) async {
    await phoneEntries(tester);
    final bytes = await _backupBytes(tester);
    await pumpRestore(tester);
    await choose(tester, bytes);

    final backupCount = await tester.runAsync(() async {
      final tables = await testBackupService(db).codec.decode(bytes);
      return tables['transactions']!.length;
    });
    expect(
      find.bySemanticsLabel(RegExp('^Step 2 of 3: Check it. Done: Choose file')),
      findsOneWidget,
    );
    expect(find.text('akatabo-backup-2026-11-12.akatabo'), findsOneWidget);
    expect(find.textContaining('saved 19 Nov 2026'), findsOneWidget);
    expect(find.text('What is in this backup'), findsOneWidget);
    expect(find.bySemanticsLabel('$backupCount transactions'), findsOneWidget);
    expect(find.bySemanticsLabel('2 budgets'), findsOneWidget);
    expect(find.textContaining('2 entries from 13 to 19 November'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'The backup covers 1 March to 12 November. This phone covers 13 to 19 November.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Add what is missing. Keeps your 2 entries not in the backup. Adds $backupCount entries '
        'from the backup.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your 2 entries not in the backup would be lost'), findsOneWidget);
    expect(find.text('Restore $backupCount transactions'), findsOneWidget);

    await tester.tap(find.text('Restore $backupCount transactions'));
    await settle(tester, rounds: 10);
    expect(find.text('Restore finished'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Step 3 of 3: Restore')), findsOneWidget);
    expect(await _entries(tester, db), backupCount! + 2);
  });

  testWidgets('replacing asks first, then leaves only the backup', (tester) async {
    await phoneEntries(tester);
    final bytes = await _backupBytes(tester);
    await pumpRestore(tester);
    await choose(tester, bytes);

    await tester.tap(find.text('Replace everything on this phone'));
    await tester.pump();
    final restore = find.textContaining(RegExp(r'^Restore \d+ transactions$'));
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.text('Replace everything on this phone?'), findsOneWidget);
    expect(
      find.textContaining('The 2 entries only this phone has will be deleted'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await _entries(tester, db), 2, reason: 'nothing changed on Cancel');

    await tester.tap(restore);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace everything'));
    await settle(tester, rounds: 10);
    expect(find.text('Restore finished'), findsOneWidget);
    final descriptions = await tester.runAsync(() => db.select(db.transactions).get());
    expect(descriptions!.map((t) => t.description), isNot(contains('Boda')));
  });

  group('a protected backup', () {
    testWidgets('asks for the password, says when it is wrong, opens with the right one', (
      tester,
    ) async {
      final bytes = await _backupBytes(tester, password: 'kampala-26');
      await pumpRestore(tester);
      await choose(tester, bytes);

      expect(find.textContaining('protected with a password'), findsOneWidget);
      expect(find.text('Open the backup'), findsOneWidget);
      await tester.tap(find.text('Open the backup'));
      await tester.pump();
      expect(find.text('Type the password to open the backup.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kampala-62');
      await tester.tap(find.text('Open the backup'));
      await settle(tester, rounds: 10);
      expect(find.textContaining('That password does not open this backup'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'kampala-26');
      await tester.tap(find.text('Open the backup'));
      await settle(tester, rounds: 10);
      expect(find.textContaining('password accepted'), findsOneWidget);
      expect(find.text('What is in this backup'), findsOneWidget);
    });
  });

  group('errors, each with a way on', () {
    testWidgets('not an Akatabo file', (tester) async {
      await pumpRestore(tester);
      await choose(tester, Uint8List.fromList(utf8.encode('Date,Amount\n')), name: 'export.csv');
      expect(find.text('This is not an Akatabo backup'), findsOneWidget);
      expect(find.text('Choose another file'), findsOneWidget);
    });

    testWidgets('a damaged file', (tester) async {
      final bytes = await _backupBytes(tester);
      await pumpRestore(tester);
      await choose(tester, Uint8List.sublistView(bytes, 0, bytes.length - 30));
      expect(find.text('This backup cannot be read'), findsOneWidget);
      expect(find.text('Choose another file'), findsOneWidget);

      // The way on: choosing a good copy.
      files.toPick = (name: 'good.akatabo', bytes: bytes);
      await tester.tap(find.text('Choose another file'));
      await settle(tester, rounds: 10);
      expect(find.text('What is in this backup'), findsOneWidget);
    });

    testWidgets('a file from a newer Akatabo', (tester) async {
      final bytes = await tester.runAsync(() async {
        final source = memoryDb();
        final newer = BackupCodec(schemaVersion: 99, keys: CountingKeys().deriver);
        final tables = await testBackupService(source).store.readAll();
        await source.close();
        return newer.encode(tables, appVersion: '2.0.0+9', now: DateTime(2027));
      });
      await pumpRestore(tester);
      await choose(tester, bytes!);
      expect(find.text('This backup is from a newer Akatabo'), findsOneWidget);
      expect(find.textContaining('saved by Akatabo 2.0.0+9'), findsOneWidget);
      expect(find.textContaining('Update Akatabo'), findsOneWidget);
    });
  });

  test('day ranges read as plain words', () {
    expect(describeDayRange(20261113, 20261119), 'from 13 to 19 November');
    expect(describeDayRange(20261030, 20261102), 'from 30 October to 2 November');
    expect(describeDayRange(20261119, 20261119), 'on 19 November');
    expect(describeDayRange(20251230, 20260102), 'from 30 December 2025 to 2 January 2026');
  });

  for (final b in Brightness.values) {
    testWidgets('golden, check step, ${b.name}', (tester) async {
      await phoneEntries(tester);
      final bytes = await _backupBytes(tester);
      await pumpRestore(tester, brightness: b);
      await choose(tester, bytes);
      await expectLater(
        find.byType(RestoreScreen),
        matchesGoldenFile('goldens/restore_check_${b.name}.png'),
      );
    });
  }
}
