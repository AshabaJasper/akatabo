// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldCategoriesData = <v1.CategoriesData>[];
    final expectedNewCategoriesData = <v2.CategoriesData>[];

    final oldAccountsData = <v1.AccountsData>[];
    final expectedNewAccountsData = <v2.AccountsData>[];

    final oldTransactionsData = <v1.TransactionsData>[];
    final expectedNewTransactionsData = <v2.TransactionsData>[];

    final oldRegularPaymentsData = <v1.RegularPaymentsData>[];
    final expectedNewRegularPaymentsData = <v2.RegularPaymentsData>[];

    final oldSettingsData = <v1.SettingsData>[];
    final expectedNewSettingsData = <v2.SettingsData>[];

    final oldForecastSnapshotsData = <v1.ForecastSnapshotsData>[];
    final expectedNewForecastSnapshotsData = <v2.ForecastSnapshotsData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, oldCategoriesData);
        batch.insertAll(oldDb.accounts, oldAccountsData);
        batch.insertAll(oldDb.transactions, oldTransactionsData);
        batch.insertAll(oldDb.regularPayments, oldRegularPaymentsData);
        batch.insertAll(oldDb.settings, oldSettingsData);
        batch.insertAll(oldDb.forecastSnapshots, oldForecastSnapshotsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewCategoriesData,
          await newDb.select(newDb.categories).get(),
        );
        expect(
          expectedNewAccountsData,
          await newDb.select(newDb.accounts).get(),
        );
        expect(
          expectedNewTransactionsData,
          await newDb.select(newDb.transactions).get(),
        );
        expect(
          expectedNewRegularPaymentsData,
          await newDb.select(newDb.regularPayments).get(),
        );
        expect(
          expectedNewSettingsData,
          await newDb.select(newDb.settings).get(),
        );
        expect(
          expectedNewForecastSnapshotsData,
          await newDb.select(newDb.forecastSnapshots).get(),
        );
      },
    );
  });

  test('v2 to v3 makes the default mobile-money and bank accounts ask for the '
      'fee, and leaves Cash and the person\'s own accounts alone', () async {
    v2.AccountsData account(String id, String kind) => v2.AccountsData(
      id: id,
      createdAt: 0,
      updatedAt: 0,
      name: id,
      kind: kind,
      colourToken: 'acct-bank',
      openingBalance: 0,
      askFeeEachTime: 0,
      countInTotals: 1,
      enabled: 1,
      isDefault: 0,
      sortOrder: 0,
    );
    final old = [
      account('acct.cash', 'cash'),
      account('acct.mtn', 'mtn'),
      account('acct.airtel', 'airtel'),
      account('acct.bank', 'bank'),
      account('own.bank', 'bank'),
    ];
    final expected = {
      'acct.cash': 0,
      'acct.mtn': 1,
      'acct.airtel': 1,
      'acct.bank': 1,
      'own.bank': 0,
    };

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) => batch.insertAll(oldDb.accounts, old),
      validateItems: (newDb) async {
        final rows = await newDb.select(newDb.accounts).get();
        expect({for (final r in rows) r.id: r.askFeeEachTime}, expected);
      },
    );
  });

  test(
    'v3 to v4 keeps every entry in shillings, with no foreign currency',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.customStatement(
          "INSERT INTO transactions (id, created_at, updated_at, direction, amount, "
          "account_id, occurred_at, local_day) VALUES "
          "('tx.1', 0, 0, 'moneyOut', 5000, 'acct.cash', 0, 20261120)",
        ),
        validateItems: (newDb) async {
          final rows = await newDb.select(newDb.transactions).get();
          expect(rows, hasLength(1));
          expect(rows.single.amount, 5000);
          expect(rows.single.foreignCurrency, isNull);
          expect(rows.single.foreignAmountMinor, isNull);
          expect(rows.single.rateMicros, isNull);
        },
      );
    },
  );
}
