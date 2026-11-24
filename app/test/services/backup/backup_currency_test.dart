import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/remembered_rates.dart';
import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/backup_store.dart';
import 'package:akatabo/services/backup/restore_planner.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';

const _usd = 3720000000;

/// A Friday at noon, when the foreign entry was made.
final _when = DateTime(2026, 11, 20, 12);

/// Adds a dollar payment: 100 USD at 3,720, so 372,000 shillings.
Future<String> _addDollars(AppDatabase db) async {
  const accountId = DefaultIds.cash;
  const categoryId = DefaultIds.food;
  return withClock(Clock.fixed(_when), () {
    return TransactionRepository(db).add(
      TransactionDraft(
        direction: Direction.moneyOut,
        amount: 372000,
        description: 'Software licence',
        categoryId: categoryId,
        accountId: accountId,
        occurredAt: _when,
        foreignCurrency: 'USD',
        foreignAmountMinor: 10000,
        rateMicros: _usd,
      ),
    );
  });
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

  test('a foreign entry and its remembered rate survive a backup and restore', () async {
    final id = await _addDollars(source);
    await SettingsRepository(source).write(rateSetting('USD'), '$_usd');

    final bytes = await testBackupService(source).createFile();
    final service = testBackupService(target);
    final opened = await service.open(bytes);
    await service.restore(opened, RestoreMode.replaceAll);

    final tx = await TransactionRepository(target).byId(id);
    expect(tx, isNotNull);
    expect(tx!.amount, 372000);
    expect(tx.foreignCurrency, 'USD');
    expect(tx.foreignAmountMinor, 10000);
    expect(tx.rateMicros, _usd);
    final stored = await target.select(target.settings).get();
    expect(rememberedRates({for (final r in stored) r.key: r.value}), {'USD': _usd});
  });

  test('a backup from before this version restores, with its entries in shillings', () async {
    // The same phone, written the way the previous version wrote it: schema 3, and no
    // foreign columns in any transaction.
    final tables = await BackupStore(source).readAll();
    final transactions = tables['transactions']!;
    for (final row in transactions) {
      row
        ..remove('foreignCurrency')
        ..remove('foreignAmountMinor')
        ..remove('rateMicros');
    }
    final oldCodec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
    final bytes = await oldCodec.encode(tables, appVersion: '0.9.0', now: DateTime(2026, 11));

    final service = testBackupService(target);
    final opened = await service.open(bytes);
    await service.restore(opened, RestoreMode.replaceAll);

    final restored = await TransactionRepository(target).listAll();
    expect(restored, isNotEmpty);
    expect(restored.every((t) => t.foreignCurrency == null), isTrue);
    expect(restored.every((t) => t.rateMicros == null), isTrue);
    expect(
      restored.map((t) => t.amount).toList()..sort(),
      (await TransactionRepository(source).listAll()).map((t) => t.amount).toList()..sort(),
    );
  });

  test('a file from a newer version is still refused', () async {
    final tables = await BackupStore(source).readAll();
    // One above this app's schema, so the test stays right when the schema moves on.
    final newer = BackupCodec(
      schemaVersion: target.schemaVersion + 1,
      keys: CountingKeys().deriver,
    );
    final bytes = await newer.encode(tables, appVersion: '9.9.9', now: DateTime(2026, 11));
    expect(
      () => testBackupService(target).open(bytes),
      throwsA(
        isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.newerVersion),
      ),
    );
  });
}
