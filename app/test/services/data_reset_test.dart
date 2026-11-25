import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/data_reset.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleting everything leaves only the first-launch defaults', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final defaults = (
      categories: (await db.select(db.categories).get()).length,
      accounts: (await db.select(db.accounts).get()).length,
    );

    await TransactionRepository(db).add(
      TransactionDraft(
        direction: Direction.moneyOut,
        amount: 45000,
        accountId: DefaultIds.mtn,
        categoryId: DefaultIds.food,
        occurredAt: DateTime(2026, 11, 19, 9),
      ),
    );
    await AccountRepository(db).add(name: 'Savings', kind: AccountKind.bank, makeDefault: true);
    await CategoryRepository(db).rename(DefaultIds.food, name: 'Groceries');
    await SettingsRepository(db).write(SettingKeys.monthStartsOn, 25);
    // Money set aside for a goal in a default account: its move points at that account, so
    // it must go before the accounts or the reset fails (and "Forgot your PIN?" with it).
    final now = DateTime(2026, 11, 19, 9);
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal.1',
            createdAt: now,
            updatedAt: now,
            name: 'Phone',
            colourToken: 'cat-teal',
            target: 800000,
          ),
        );
    await db
        .into(db.goalMoves)
        .insert(
          GoalMovesCompanion.insert(
            id: 'move.1',
            createdAt: now,
            updatedAt: now,
            goalId: 'goal.1',
            accountId: DefaultIds.mtn,
            amount: 100000,
            occurredAt: now,
            localDay: 20261119,
          ),
        );

    await deleteEverything(db);

    expect(await db.select(db.goalMoves).get(), isEmpty);
    expect(await db.select(db.goals).get(), isEmpty);

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.settings).get(), isEmpty);
    final accounts = await db.select(db.accounts).get();
    expect(accounts.length, defaults.accounts);
    expect(accounts.where((a) => a.isDefault).map((a) => a.id), [DefaultIds.mtn]);
    final categories = await db.select(db.categories).get();
    expect(categories.length, defaults.categories);
    expect(categories.singleWhere((c) => c.id == DefaultIds.food).name, isNot('Groceries'));
  });
}
