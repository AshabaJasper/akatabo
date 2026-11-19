import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../seed/default_data.dart';
import 'app_database.steps.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Transactions, Categories, Accounts, RegularPayments, Settings, ForecastSnapshots],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  /// The database lives in the app's private support folder. Android backup is off for it.
  static QueryExecutor _open() => driftDatabase(
    name: 'akatabo',
    native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await insertDefaultData(this);
    },
    // Each step comes from `dart run drift_dev make-migrations`, which also writes its test.
    onUpgrade: stepByStep(
      // v2: when a budget started, so carry-over waits until it has covered a whole month.
      from1To2: (m, schema) async {
        await m.addColumn(schema.categories, schema.categories.budgetSince);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
