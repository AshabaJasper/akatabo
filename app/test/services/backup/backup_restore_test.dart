import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/services/backup/backup_store.dart';
import 'package:akatabo/services/backup/restore_planner.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_seed.dart';

/// Every table, each sorted by its key, so two databases compare by content.
Future<BackupTables> _all(AppDatabase db) async {
  final tables = await BackupStore(db).readAll();
  for (final MapEntry(key: t, value: rows) in tables.entries) {
    rows.sort((a, b) => RestorePlanner.keyOf(t, a).compareTo(RestorePlanner.keyOf(t, b)));
  }
  return tables;
}

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() async {
    source = memoryDb();
    target = memoryDb();
    await seedFullPhone(source);
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  group('round trip', () {
    for (final password in [null, 'kampala-2026']) {
      test('restoring onto an empty phone gives back every table (password: $password)', () async {
        final bytes = await testBackupService(source).createFile(password: password);
        final service = testBackupService(target);
        final opened = await service.open(bytes, password: password);
        await service.restore(opened, RestoreMode.replaceAll);
        expect(await _all(target), await _all(source));
      });
    }

    test('every table is in the file, counted in its header', () async {
      final bytes = await testBackupService(source).createFile();
      final header = testBackupService(target).codec.readHeader(bytes);
      final tables = await _all(source);
      for (final t in BackupFormat.tables) {
        expect(header.counts[t], tables[t]!.length, reason: t);
        expect(header.counts[t], greaterThan(0), reason: '$t is seeded');
      }
    });
  });

  group('add what is missing', () {
    test('adds the backup entries, keeps this phone\'s, and the newer copy wins', () async {
      final bytes = await testBackupService(source).createFile();
      // The target phone: one entry of its own, and one shared entry it changed later.
      final shared = (await source.select(source.transactions).get()).first;
      await target
          .into(target.transactions)
          .insert(shared.copyWith(amount: 77777, updatedAt: DateTime(2026, 12)));
      final older = (await source.select(source.transactions).get())[1];
      await target
          .into(target.transactions)
          .insert(older.copyWith(amount: 1, updatedAt: DateTime(2026)));
      final mine = await addEntry(target, DateTime(2026, 11, 19), description: 'Boda');

      final service = testBackupService(target);
      final opened = await service.open(bytes);
      final p = opened.preview;
      final sourceCount = (await source.select(source.transactions).get()).length;
      expect(p.backupTransactions, sourceCount);
      expect(p.phoneOnly, 1);
      expect((p.phoneOnlyFirstDay, p.phoneOnlyLastDay), (20261119, 20261119));
      expect(p.toAdd, sourceCount - 2);
      expect(p.toUpdate, 1);
      expect(p.phoneNewer, 1);

      await service.restore(opened, RestoreMode.addMissing);
      final after = {for (final t in await target.select(target.transactions).get()) t.id: t};
      expect(after.length, sourceCount + 1);
      expect(after[mine], isNotNull);
      expect(after[shared.id]!.amount, 77777, reason: 'this phone changed it later');
      expect(after[older.id]!.amount, older.amount, reason: 'the backup changed it later');
    });

    test('a new phone takes the backup\'s edited defaults over its own blank ones', () async {
      // Edited on the old phone in October; the new phone's defaults were seeded now, so
      // they carry a later stamp but were never touched.
      await withClock(Clock.fixed(DateTime(2026, 10, 2)), () async {
        await AccountRepository(source).setBalanceToday(DefaultIds.cash, 250000);
        await CategoryRepository(source)
            .setBudget(DefaultIds.food, monthlyBudget: 300000, carriesOver: false, warnAt: 80);
      });
      final bytes = await testBackupService(source).createFile();

      final service = testBackupService(target);
      final opened = await service.open(bytes);
      expect(opened.preview.addMissingChangesSomething, isTrue);
      await service.restore(opened, RestoreMode.addMissing);

      final cash = await (target.select(
        target.accounts,
      )..where((a) => a.id.equals(DefaultIds.cash))).getSingle();
      expect(cash.openingBalance, 250000);
      expect(cash.balanceAt, isNotNull);
      final food = await (target.select(
        target.categories,
      )..where((c) => c.id.equals(DefaultIds.food))).getSingle();
      expect(food.monthlyBudget, 300000);
    });

    test('a default this phone edited after the backup is kept', () async {
      await withClock(
        Clock.fixed(DateTime(2026, 10, 2)),
        () => AccountRepository(source).setBalanceToday(DefaultIds.cash, 250000),
      );
      final bytes = await testBackupService(source).createFile();
      // Open (and seed) the new phone now, so its defaults are made before they are edited.
      await target.select(target.accounts).get();
      await withClock(
        Clock.fixed(DateTime(2027, 1, 5)),
        () => AccountRepository(target).setBalanceToday(DefaultIds.cash, 40000),
      );

      final service = testBackupService(target);
      await service.restore(await service.open(bytes), RestoreMode.addMissing);
      final cash = await (target.select(
        target.accounts,
      )..where((a) => a.id.equals(DefaultIds.cash))).getSingle();
      expect(cash.openingBalance, 40000);
    });

    test('a second restore of the same file adds nothing', () async {
      final bytes = await testBackupService(source).createFile();
      final service = testBackupService(target);
      await service.restore(await service.open(bytes), RestoreMode.addMissing);
      final again = await service.open(bytes);
      expect(again.preview.toAdd, 0);
      expect(again.preview.addMissingChangesSomething, isFalse);
    });

    test('only one account stays picked first', () async {
      final bytes = await testBackupService(source).createFile();
      // The backup marks Cash as picked first; this phone, later, marks Airtel.
      await (source.update(source.accounts)..where((a) => a.id.equals(DefaultIds.cash))).write(
        AccountsCompanion(isDefault: const Value(true), updatedAt: Value(DateTime(2026))),
      );
      final marked = await testBackupService(source).createFile();
      expect(marked, isNot(bytes));
      await withClock(
        Clock.fixed(DateTime(2026, 11, 19)),
        () => AccountRepository(target).setDefault(DefaultIds.airtel),
      );
      final service = testBackupService(target);
      await service.restore(await service.open(marked), RestoreMode.addMissing);
      final defaults = await (target.select(
        target.accounts,
      )..where((a) => a.isDefault.equals(true))).get();
      expect([for (final a in defaults) a.id], [DefaultIds.airtel]);
    });
  });

  group('replace everything', () {
    test('leaves this phone equal to the backup', () async {
      final bytes = await testBackupService(source).createFile();
      await addEntry(target, DateTime(2026, 11, 19), description: 'Boda');
      await withClock(
        Clock.fixed(DateTime(2026, 11, 19)),
        () => CategoryRepository(target).add(
          name: 'Only here',
          kind: CategoryKind.spending,
          iconKey: 'star',
          colourToken: 'cat-red',
        ),
      );
      final service = testBackupService(target);
      final opened = await service.open(bytes);
      expect(opened.preview.lostByReplacing, 1);
      await service.restore(opened, RestoreMode.replaceAll);
      expect(await _all(target), await _all(source));
    });

    test('keeps this phone\'s backup and lock settings', () async {
      await SettingsRepository(source).write(BackupKeys.lastAt, 111);
      final bytes = await testBackupService(source).createFile();
      await SettingsRepository(target).write(BackupKeys.lastAt, 222);
      await SettingsRepository(target).write(BackupKeys.weekly, true);
      final service = testBackupService(target);
      await service.restore(await service.open(bytes), RestoreMode.replaceAll);
      expect(await SettingsRepository(target).read(BackupKeys.lastAt), 222);
      expect(await SettingsRepository(target).read(BackupKeys.weekly), isTrue);
    });
  });

  group('all or nothing', () {
    test('a restore that fails part way leaves the phone as it was', () async {
      final bytes = await testBackupService(source).createFile();
      await addEntry(target, DateTime(2026, 11, 19), description: 'Boda');
      final before = await _all(target);
      final service = testBackupService(target);
      final opened = await service.open(bytes);
      // The last entry points at a category that is nowhere: the foreign key stops the
      // restore after many rows were already written.
      final tables = {
        for (final e in opened.tables.entries) e.key: [...e.value],
      };
      final bad = {...tables['transactions']!.last, 'categoryId': 'cat.nowhere'};
      tables['transactions']!.last = bad;
      final broken = OpenedBackup(header: opened.header, tables: tables, preview: opened.preview);
      for (final mode in RestoreMode.values) {
        await expectLater(service.restore(broken, mode), throwsA(anything), reason: mode.name);
        expect(await _all(target), before, reason: mode.name);
      }
    });

    test('rows the app cannot store are refused as damaged before anything is asked', () {
      final tables = {for (final t in BackupFormat.tables) t: <Map<String, Object?>>[]};
      tables['transactions'] = [
        {'id': 'x', 'amount': 'lots'},
      ];
      expect(
        () => BackupStore.checkRows(tables),
        throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.damaged)),
      );
    });
  });

  test('the file name carries the day', () {
    expect(BackupService.fileNameFor(DateTime(2026, 11, 9)), 'akatabo-backup-2026-11-09.akatabo');
  });
}
