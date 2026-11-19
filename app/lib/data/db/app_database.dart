import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../seed/default_data.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Transactions, Categories, Accounts, RegularPayments, Settings, ForecastSnapshots],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

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
    // Later versions add steps here from `dart run drift_dev make-migrations`.
    onUpgrade: (m, from, to) async {},
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
