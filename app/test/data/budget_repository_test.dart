import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository cats;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cats = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<Category> food() =>
      (db.select(db.categories)..where((c) => c.id.equals(DefaultIds.food))).getSingle();

  Future<void> setOn(DateTime day, {int? amount = 200000, bool carry = true}) => withClock(
    Clock.fixed(day),
    () => cats.setBudget(DefaultIds.food, monthlyBudget: amount, carriesOver: carry, warnAt: 80),
  );

  group('when a budget started', () {
    test('a new budget starts its clock on the day it is set', () async {
      await setOn(DateTime(2026, 9, 14, 10));
      expect((await food()).budgetSince, 20260914);
    });

    test('changing the amount keeps the start day', () async {
      await setOn(DateTime(2026, 9, 14, 10));
      await setOn(DateTime(2026, 11, 19, 10), amount: 250000);
      expect((await food()).budgetSince, 20260914);
    });

    test('switching carry-over on restarts the clock', () async {
      await setOn(DateTime(2026, 9, 14, 10), carry: false);
      await setOn(DateTime(2026, 11, 19, 10));
      expect((await food()).budgetSince, 20261119);
    });

    test('removing the budget clears it', () async {
      await setOn(DateTime(2026, 9, 14, 10));
      await setOn(DateTime(2026, 11, 19, 10), amount: null, carry: false);
      final row = await food();
      expect(row.monthlyBudget, isNull);
      expect(row.budgetSince, isNull);
    });
  });
}
