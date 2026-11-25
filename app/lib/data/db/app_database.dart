import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../seed/default_data.dart';
import 'app_database.steps.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    Categories,
    Accounts,
    RegularPayments,
    Settings,
    ForecastSnapshots,
    Goals,
    GoalMoves,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 5;

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
      // v3: when each account's balance was set (null until the person sets it), and the
      // default mobile-money and bank accounts ask for the fee, as a new install's do. Before
      // v3 no screen could set the fee choice on them, so it was always off and no choice of
      // the person's is overwritten. Cash has no fee and stays off.
      from2To3: (m, schema) async {
        await m.addColumn(schema.accounts, schema.accounts.balanceAt);
        await customUpdate(
          'UPDATE accounts SET ask_fee_each_time = 1 WHERE id IN (?, ?, ?)',
          variables: [
            Variable.withString(DefaultIds.mtn),
            Variable.withString(DefaultIds.airtel),
            Variable.withString(DefaultIds.bank),
          ],
          updates: {accounts},
        );
      },
      // v4: a transaction can keep the foreign currency it was paid in, its amount there and
      // the rate typed for it. Old rows stay in shillings, with all three empty.
      from3To4: (m, schema) async {
        await m.addColumn(schema.transactions, schema.transactions.foreignCurrency);
        await m.addColumn(schema.transactions, schema.transactions.foreignAmountMinor);
        await m.addColumn(schema.transactions, schema.transactions.rateMicros);
      },
      // v5: savings goals. A goal and the moves that set money aside for it inside an account,
      // kept apart from transactions so totals, budgets and the forecast never count them.
      from4To5: (m, schema) async {
        await m.createTable(schema.goals);
        await m.createTable(schema.goalMoves);
        await m.createIndex(schema.goalMoveGoal);
        await m.createIndex(schema.goalMoveAccount);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
