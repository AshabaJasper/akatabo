import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter_test_config.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<Category> row(String id) =>
      (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();

  Future<String> addEntry(String categoryId, {String id = 'tx1'}) async {
    await TransactionRepository(db).add(
      TransactionDraft(
        direction: Direction.moneyOut,
        amount: 5000,
        accountId: DefaultIds.mtn,
        occurredAt: DateTime(2026, 11, 19, 9),
        categoryId: categoryId,
      ),
    );
    return id;
  }

  group('update', () {
    test('saves the name, icon and colour, trimmed', () async {
      await repo.update(
        DefaultIds.transport,
        name: '  Boda and taxi ',
        iconKey: 'fuel',
        colourToken: 'cat-red',
      );
      final r = await row(DefaultIds.transport);
      expect((r.name, r.iconKey, r.colourToken), ('Boda and taxi', 'fuel', 'cat-red'));
    });

    test('refuses an empty name and a name another category has, ignoring case', () async {
      await expectLater(
        repo.update(DefaultIds.food, name: '  ', iconKey: 'basket', colourToken: 'cat-green'),
        throwsArgumentError,
      );
      await expectLater(
        repo.update(
          DefaultIds.food,
          name: 'transport ',
          iconKey: 'basket',
          colourToken: 'cat-green',
        ),
        throwsA(isA<CategoryNameTaken>()),
      );
      expect((await row(DefaultIds.food)).name, 'Food and shopping');
      // Its own name, in another case, is fine.
      await repo.update(
        DefaultIds.food,
        name: 'FOOD AND SHOPPING',
        iconKey: 'basket',
        colourToken: 'cat-green',
      );
      expect((await row(DefaultIds.food)).name, 'FOOD AND SHOPPING');
    });

    test('rename refuses a name another category has too', () async {
      await expectLater(
        repo.rename(DefaultIds.food, name: 'Bills'),
        throwsA(isA<CategoryNameTaken>()),
      );
    });

    test('refuses a colour that is not a category colour', () async {
      await expectLater(
        repo.update(DefaultIds.food, name: 'Food', iconKey: 'basket', colourToken: 'acct-mtn'),
        throwsArgumentError,
      );
    });

    test('a budget set here behaves like one from Set a budget', () async {
      await atTestNow(
        () => repo.update(
          DefaultIds.transport,
          name: 'Transport',
          iconKey: 'bus',
          colourToken: 'cat-amber',
          changeBudget: true,
          monthlyBudget: 200000,
        ),
      );
      var r = await row(DefaultIds.transport);
      expect((r.monthlyBudget, r.budgetWarnAt, r.budgetSince), (200000, 80, 20261119));

      // Carry-over and warn level chosen on Set a budget survive an amount change here,
      // and the carry-over clock keeps its start.
      await repo.setBudget(
        DefaultIds.transport,
        monthlyBudget: 200000,
        carriesOver: true,
        warnAt: 90,
      );
      final since = (await row(DefaultIds.transport)).budgetSince;
      await repo.update(
        DefaultIds.transport,
        name: 'Transport',
        iconKey: 'bus',
        colourToken: 'cat-amber',
        changeBudget: true,
        monthlyBudget: 250000,
      );
      r = await row(DefaultIds.transport);
      expect((r.monthlyBudget, r.budgetCarriesOver, r.budgetWarnAt), (250000, true, 90));
      expect(r.budgetSince, since);

      // Removing it clears everything, as "Remove budget" does.
      await repo.update(
        DefaultIds.transport,
        name: 'Transport',
        iconKey: 'bus',
        colourToken: 'cat-amber',
        changeBudget: true,
      );
      r = await row(DefaultIds.transport);
      expect(
        (r.monthlyBudget, r.budgetCarriesOver, r.budgetWarnAt, r.budgetSince),
        (null, false, 80, null),
      );
    });

    test('Fees and tax cannot get a budget, and nothing is saved when it is refused', () async {
      await expectLater(
        repo.update(
          DefaultIds.fees,
          name: 'Fees',
          iconKey: 'cash',
          colourToken: 'cat-pink',
          changeBudget: true,
          monthlyBudget: 10000,
        ),
        throwsArgumentError,
      );
      final r = await row(DefaultIds.fees);
      expect((r.name, r.monthlyBudget), ('Fees and tax', null));
    });
  });

  group('delete', () {
    test('moves entries and regular payments to Other and removes the budget', () async {
      await repo.setBudget(DefaultIds.health, monthlyBudget: 50000, carriesOver: false, warnAt: 80);
      await addEntry(DefaultIds.health);
      await addEntry(DefaultIds.health);
      await RegularPaymentRepository(db).add(
        label: 'Clinic',
        amount: 20000,
        intervalDays: 30,
        nextDueOn: 20261201,
        categoryId: DefaultIds.health,
      );
      expect(await repo.entryCount(DefaultIds.health), 2);

      expect(await repo.delete(DefaultIds.health), 2);

      final cats = await db.select(db.categories).get();
      expect(cats.any((c) => c.id == DefaultIds.health), isFalse);
      final entries = await db.select(db.transactions).get();
      expect(entries.map((t) => t.categoryId), everyElement(DefaultIds.other));
      final regular = await db.select(db.regularPayments).getSingle();
      expect(regular.categoryId, DefaultIds.other);
    });

    test('a money-in category moves its entries to Other money in', () async {
      await TransactionRepository(db).add(
        TransactionDraft(
          direction: Direction.moneyIn,
          amount: 90000,
          accountId: DefaultIds.mtn,
          occurredAt: DateTime(2026, 11, 19, 9),
          categoryId: DefaultIds.gifts,
        ),
      );
      await repo.delete(DefaultIds.gifts);
      final t = await db.select(db.transactions).getSingle();
      expect(t.categoryId, DefaultIds.otherIn);
    });

    test('Fees and tax and the two Other categories cannot be deleted', () async {
      for (final id in [DefaultIds.fees, DefaultIds.other, DefaultIds.otherIn]) {
        await expectLater(repo.delete(id), throwsStateError, reason: id);
        expect(await row(id), isNotNull);
      }
    });
  });

  group('reorder', () {
    Future<List<String>> order() async => [for (final c in await repo.watchAll().first) c.id];

    test('puts the named categories in the new order and leaves the rest in place', () async {
      final before = await order();
      final spending = [
        for (final c in await repo.watch(CategoryKind.spending, includeHidden: true).first)
          if (!c.isSystem) c.id,
      ];
      final reversed = spending.reversed.toList();

      await repo.reorder(reversed);

      final after = await order();
      // Fees and tax and every money-in category keep their places.
      for (final id in before.where((id) => !spending.contains(id))) {
        expect(after.indexOf(id), before.indexOf(id), reason: id);
      }
      final shownSpending = [
        for (final c in await repo.watch(CategoryKind.spending).first)
          if (!c.isSystem) c.id,
      ];
      expect(shownSpending, reversed);
    });

    test('moving one up changes only that pair', () async {
      final spending = [
        for (final c in await repo.watch(CategoryKind.spending).first)
          if (!c.isSystem) c.id,
      ];
      final moved = [...spending]..insert(0, spending[1]);
      moved.removeAt(2);
      await repo.reorder(moved);
      final again = [
        for (final c in await repo.watch(CategoryKind.spending).first)
          if (!c.isSystem) c.id,
      ];
      expect(again, moved);
    });

    test('ties in the stored order are broken by name and renumbered on reorder', () async {
      await db.update(db.categories).write(const CategoriesCompanion(sortOrder: Value(0)));
      final names = [for (final c in await repo.watchAll().first) c.name];
      expect(names, [...names]..sort());
      final ids = [for (final c in await repo.watch(CategoryKind.income).first) c.id];
      await repo.reorder(ids.reversed.toList());
      expect([for (final c in await repo.watch(CategoryKind.income).first) c.id], ids.reversed);
    });

    test('refuses a list with an unknown or repeated id', () async {
      await expectLater(repo.reorder(['nope']), throwsArgumentError);
      await expectLater(repo.reorder([DefaultIds.food, DefaultIds.food]), throwsArgumentError);
    });
  });
}
