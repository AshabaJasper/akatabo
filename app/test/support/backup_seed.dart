import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'fake_backup.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

BackupService testBackupService(AppDatabase db, {CountingKeys? keys}) =>
    BackupService(db, keys: (keys ?? CountingKeys()).deriver, appVersion: () async => '0.1.0+1');

/// Adds an entry on [day] (a date) at noon, with the clock at that moment.
Future<String> addEntry(
  AppDatabase db,
  DateTime day, {
  int amount = 10000,
  String description = 'Lunch',
  String categoryId = DefaultIds.food,
}) => withClock(
  Clock.fixed(DateTime(day.year, day.month, day.day, 12)),
  () => TransactionRepository(db).add(
    TransactionDraft(
      direction: Direction.moneyOut,
      amount: amount,
      accountId: DefaultIds.mtn,
      categoryId: categoryId,
      description: description,
      occurredAt: DateTime(day.year, day.month, day.day, 12),
    ),
  ),
);

/// A phone with something in every table: entries from March to 12 November, a budget, a
/// new category and account, a regular payment, settings and a saved forecast.
Future<void> seedFullPhone(AppDatabase db) async {
  await withClock(Clock.fixed(DateTime(2026, 3, 1, 8)), () async {
    final rent = await CategoryRepository(db).add(
      name: 'Rent',
      kind: CategoryKind.spending,
      iconKey: 'house',
      colourToken: 'cat-teal',
      monthlyBudget: 400000,
    );
    await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank, openingBalance: 5000);
    await RegularPaymentRepository(
      db,
    ).add(label: 'Rent', amount: 400000, intervalDays: 30, nextDueOn: 20261201, categoryId: rent);
    await SettingsRepository(db).write(SettingKeys.monthStartsOn, 25);
    await SettingsRepository(db).write(SettingKeys.suggestCategory, false);
  });
  for (
    var d = DateTime(2026, 3);
    d.isBefore(DateTime(2026, 11, 13));
    d = d.add(const Duration(days: 9))
  ) {
    await addEntry(db, d, amount: 1000 + d.day * 100);
  }
  await addEntry(db, DateTime(2026, 11, 12), amount: 45000, description: 'Yaka');
  await db
      .into(db.forecastSnapshots)
      .insert(
        ForecastSnapshotsCompanion.insert(
          periodStart: 20261101,
          takenOn: 20261110,
          point: 900000,
          low: 800000,
          high: 1000000,
          spentSoFar: 400000,
          createdAt: DateTime(2026, 11, 10, 9),
        ),
      );
  await (db.update(db.categories)..where((c) => c.id.equals(DefaultIds.food))).write(
    CategoriesCompanion(monthlyBudget: const Value(300000), updatedAt: Value(DateTime(2026, 3, 2))),
  );
}
