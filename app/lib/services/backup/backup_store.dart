import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';
import 'backup_codec.dart';
import 'restore_planner.dart';

/// Moves rows between the database and the JSON tables of a backup file.
///
/// Rows travel as drift's own JSON for each data class, so every column of every table is
/// included and read back exactly as stored.
class BackupStore {
  BackupStore(this.db);
  final AppDatabase db;

  /// Every row of every table on this phone.
  Future<BackupTables> readAll() => db.transaction(() async {
    List<Map<String, Object?>> json(List<DataClass> rows) => [for (final r in rows) r.toJson()];
    return {
      'accounts': json(await db.select(db.accounts).get()),
      'categories': json(await db.select(db.categories).get()),
      'regularPayments': json(await db.select(db.regularPayments).get()),
      'transactions': json(await db.select(db.transactions).get()),
      'settings': json(await db.select(db.settings).get()),
      'forecastSnapshots': json(await db.select(db.forecastSnapshots).get()),
      'goals': json(await db.select(db.goals).get()),
      'goalMoves': json(await db.select(db.goalMoves).get()),
    };
  });

  /// Reads every row of a backup as this app's data classes, so a file whose rows cannot
  /// be stored is refused as damaged before the person is asked anything.
  static void checkRows(BackupTables tables) {
    try {
      for (final table in BackupFormat.tables) {
        for (final row in tables[table]!) {
          _fromJson(table, row);
        }
      }
    } catch (_) {
      throw const BackupException(BackupProblem.damaged);
    }
  }

  static Insertable<DataClass> _fromJson(String table, Map<String, Object?> row) => switch (table) {
    'accounts' => Account.fromJson(row),
    'categories' => Category.fromJson(row),
    'regularPayments' => RegularPayment.fromJson(row),
    'transactions' => Transaction.fromJson(row),
    'settings' => Setting.fromJson(row),
    'forecastSnapshots' => ForecastSnapshot.fromJson(row),
    'goals' => Goal.fromJson(row),
    'goalMoves' => GoalMove.fromJson(row),
    _ => throw ArgumentError.value(table, 'table'),
  } as Insertable<DataClass>;

  TableInfo<Table, DataClass> _table(String name) => switch (name) {
    'accounts' => db.accounts,
    'categories' => db.categories,
    'regularPayments' => db.regularPayments,
    'transactions' => db.transactions,
    'settings' => db.settings,
    'forecastSnapshots' => db.forecastSnapshots,
    'goals' => db.goals,
    'goalMoves' => db.goalMoves,
    _ => throw ArgumentError.value(name, 'table'),
  } as TableInfo<Table, DataClass>;

  Future<void> _delete(String table, List<String> keys) async {
    if (keys.isEmpty) return;
    switch (table) {
      case 'settings':
        await (db.delete(db.settings)..where((s) => s.key.isIn(keys))).go();
      case 'forecastSnapshots':
        for (final key in keys) {
          final [period, taken] = key.split('/').map(int.parse).toList();
          await (db.delete(
            db.forecastSnapshots,
          )..where((f) => f.periodStart.equals(period) & f.takenOn.equals(taken))).go();
        }
      case 'transactions':
        await (db.delete(db.transactions)..where((t) => t.id.isIn(keys))).go();
      case 'regularPayments':
        await (db.delete(db.regularPayments)..where((t) => t.id.isIn(keys))).go();
      case 'categories':
        await (db.delete(db.categories)..where((t) => t.id.isIn(keys))).go();
      case 'accounts':
        await (db.delete(db.accounts)..where((t) => t.id.isIn(keys))).go();
      case 'goals':
        await (db.delete(db.goals)..where((t) => t.id.isIn(keys))).go();
      case 'goalMoves':
        await (db.delete(db.goalMoves)..where((t) => t.id.isIn(keys))).go();
    }
  }

  /// Carries out [plan] in one database transaction: all of it happens, or none of it does.
  ///
  /// Children are removed before their parents, and parents written before their children,
  /// so foreign keys hold at every step. Afterwards only one account stays "picked first":
  /// the one marked most recently.
  Future<void> apply(RestorePlan plan) => db.transaction(() async {
    for (final t in [
      'goalMoves',
      'transactions',
      'regularPayments',
      'forecastSnapshots',
      'settings',
    ]) {
      await _delete(t, plan.deletes[t]!);
    }
    for (final t in BackupFormat.tables) {
      final table = _table(t);
      for (final row in plan.upserts[t]!) {
        await db.into(table).insertOnConflictUpdate(_fromJson(t, row));
      }
    }
    for (final t in ['goals', 'categories', 'accounts']) {
      await _delete(t, plan.deletes[t]!);
    }

    final marked =
        await (db.select(db.accounts)
              ..where((a) => a.isDefault.equals(true))
              ..orderBy([(a) => OrderingTerm.desc(a.updatedAt)]))
            .get();
    if (marked.length > 1) {
      await (db.update(db.accounts)
            ..where((a) => a.id.isIn([for (final a in marked.skip(1)) a.id])))
          .write(const AccountsCompanion(isDefault: Value(false)));
    }
  });
}
