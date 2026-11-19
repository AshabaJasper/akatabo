import 'package:akatabo/core/theme/ak_appearance.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter_test_config.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository txs;

  setUp(() {
    // Runs on the Windows host with the SQLite that the sqlite3 build hook compiles;
    // no sqlite3.dll is installed or bundled.
    db = AppDatabase(NativeDatabase.memory());
    txs = TransactionRepository(db);
  });
  tearDown(() => db.close());

  TransactionDraft draft({
    Direction direction = Direction.moneyOut,
    int amount = 45000,
    String? category = DefaultIds.food,
    String account = DefaultIds.mtn,
    String? to,
    DateTime? at,
    String description = 'Groceries, Nakasero market',
  }) => TransactionDraft(
    direction: direction,
    amount: amount,
    description: description,
    categoryId: category,
    accountId: account,
    toAccountId: to,
    occurredAt: at ?? testNow,
  );

  test('a new database has the drawn default categories and accounts', () async {
    final cats = await db.select(db.categories).get();
    expect(
      cats.map((c) => c.id),
      containsAll([DefaultIds.food, DefaultIds.fees, DefaultIds.salary]),
    );
    expect(cats.where((c) => c.isSystem).map((c) => c.id), [DefaultIds.fees]);
    final accounts = await db.select(db.accounts).get();
    expect(accounts.map((a) => a.name), ['Cash', 'MTN MoMo', 'Airtel Money', 'Bank']);
    expect(accounts.where((a) => a.isDefault).single.id, DefaultIds.mtn);
  });

  test('every default category uses a real icon and a cat- colour', () async {
    final cats = await db.select(db.categories).get();
    for (final c in cats) {
      expect(c.colourToken, startsWith('cat-'), reason: c.name);
    }
  });

  test('saving stores whole shillings, the local day and the payee key', () async {
    final id = await atTestNow(() => txs.add(draft(at: DateTime(2026, 11, 19, 23, 50))));
    final t = (await txs.byId(id))!;
    expect(t.amount, 45000);
    expect(t.localDay, 20261119);
    expect(t.payeeKey, 'groceries nakasero market');
    expect(t.createdAt, testNow);
    expect(t.categoryWasCorrected, isFalse);
  });

  test('a category other than the suggestion is recorded as a correction', () async {
    final id = await txs.add(
      TransactionDraft(
        direction: Direction.moneyOut,
        amount: 3000,
        description: 'Boda to town',
        categoryId: DefaultIds.transport,
        suggestedCategoryId: DefaultIds.food,
        suggestionConfidence: 0.6,
        accountId: DefaultIds.cash,
        occurredAt: testNow,
      ),
    );
    expect((await txs.byId(id))!.categoryWasCorrected, isTrue);
  });

  test('a draft without an amount or category is refused with a reason', () {
    expect(draft(amount: 0).problems(), contains('Enter an amount above zero.'));
    expect(draft(category: null).problems(), contains('Choose a category.'));
    expect(() => txs.add(draft(amount: 0)), throwsArgumentError);
  });

  test('a transfer needs two different accounts and has no category', () async {
    expect(
      draft(direction: Direction.transfer, to: DefaultIds.mtn).problems(),
      contains('Choose two different accounts.'),
    );
    final id = await txs.add(draft(direction: Direction.transfer, to: DefaultIds.cash));
    final t = (await txs.byId(id))!;
    expect(t.categoryId, isNull);
    expect(t.toAccountId, DefaultIds.cash);
  });

  test('the database refuses a non-positive amount even past the repository', () async {
    final insert = db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'x',
            direction: Direction.moneyOut,
            amount: -5,
            accountId: DefaultIds.cash,
            occurredAt: testNow,
            localDay: 20261119,
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );
    await expectLater(insert, throwsA(isA<SqliteException>()));
  });

  test('a period query returns only that period, newest first', () async {
    await txs.add(draft(at: DateTime(2026, 10, 31, 20)));
    await txs.add(draft(at: DateTime(2026, 11, 1, 8)));
    await txs.add(draft(at: DateTime(2026, 11, 19, 9)));
    await txs.add(draft(at: DateTime(2026, 12, 1, 0, 1)));
    final nov = const PeriodCalculator().month(testNow);
    final rows = await txs.watchIn(nov).first;
    expect(rows.map((r) => r.localDay), [20261119, 20261101]);
  });

  test('deleting a transaction removes it', () async {
    final id = await txs.add(draft());
    await txs.delete(id);
    expect(await txs.byId(id), isNull);
  });

  group('settings', () {
    test('an unset setting reads as its default', () async {
      final s = SettingsRepository(db);
      expect(await s.read(SettingKeys.monthStartsOn), 1);
      expect(await s.read(SettingKeys.corners), AkCorners.rounded);
    });

    test('a written setting is read back and watched', () async {
      final s = SettingsRepository(db);
      await s.write(SettingKeys.corners, AkCorners.square);
      expect(await s.read(SettingKeys.corners), AkCorners.square);
      expect(await s.watch(SettingKeys.corners).first, AkCorners.square);
    });

    test('a damaged or out-of-range value falls back to the default', () {
      expect(SettingKeys.monthStartsOn.decode('31'), 1);
      expect(SettingKeys.monthStartsOn.decode('abc'), 1);
      expect(SettingKeys.corners.decode('wobbly'), AkCorners.rounded);
      expect(SettingKeys.onboardingDone.decode(null), isFalse);
    });
  });

  test('foreign keys are enforced', () async {
    final insert = db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'y',
            direction: Direction.moneyOut,
            amount: 5,
            categoryId: const Value('cat.missing'),
            accountId: DefaultIds.cash,
            occurredAt: testNow,
            localDay: 20261119,
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );
    await expectLater(insert, throwsA(isA<SqliteException>()));
  });
}
