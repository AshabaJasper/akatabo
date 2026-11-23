import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/budget.dart';
import 'package:akatabo/services/notifications/budget_warning.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notifications.dart';

final _now = DateTime(2026, 11, 19, 10);

void main() {
  group('crossedBudgetLine', () {
    BudgetStatus? crossed(int before, int after, {int warnAt = 80}) => crossedBudgetLine(
      spentBefore: before,
      spentAfter: after,
      budget: 100000,
      warnAt: warnAt,
      day: 19,
      daysInMonth: 30,
    );

    test('crossing the warn level is Nearly used, once', () {
      expect(crossed(70000, 80000), BudgetStatus.nearlyUsed);
      expect(crossed(80000, 85000), isNull);
    });

    test('follows each budget\'s own level', () {
      expect(crossed(55000, 65000, warnAt: 60), BudgetStatus.nearlyUsed);
      expect(crossed(55000, 65000, warnAt: 90), isNull);
    });

    test('going over is the next line, and a jump past both warns once as Over', () {
      expect(crossed(90000, 100001), BudgetStatus.over);
      expect(crossed(10000, 120000), BudgetStatus.over);
      expect(crossed(100000, 100000), isNull, reason: 'exactly the budget is not over');
      expect(crossed(120000, 130000), isNull);
    });
  });

  group('after an entry is saved', () {
    late AppDatabase db;
    late FakeNotifications fake;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      fake = FakeNotifications();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsServiceProvider.overrideWithValue(fake),
        ],
      );
      // Riverpod pauses a provider nothing listens to.
      container.listen(storedSettingsProvider, (_, _) {});
      await container
          .read(categoryRepositoryProvider)
          .setBudget(DefaultIds.food, monthlyBudget: 100000, carriesOver: false, warnAt: 80);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> warnOn() =>
        container.read(settingsRepositoryProvider).write(SettingKeys.budgetWarn, true);

    /// Saves money out in Food, as Add does, then runs the warning.
    Future<void> spend(int amount, {DateTime? at}) => withClock(Clock.fixed(_now), () async {
      final id = await container
          .read(transactionRepositoryProvider)
          .add(
            TransactionDraft(
              direction: Direction.moneyOut,
              amount: amount,
              categoryId: DefaultIds.food,
              accountId: DefaultIds.mtn,
              occurredAt: at ?? _now,
            ),
          );
      await container.read(budgetWarnerProvider).afterSave(id);
    });

    test('one notification when the warn level is crossed, none on the next entry', () async {
      await warnOn();
      await spend(70000);
      expect(fake.shown, isEmpty);

      await spend(15000); // 85% of 100,000
      expect(fake.shown, hasLength(1));
      expect(fake.shown.single.title, 'Food and shopping is nearly used');
      expect(
        fake.shown.single.body,
        'UGX 85,000 spent of UGX 100,000 this month, UGX 15,000 left.',
      );

      await spend(5000); // 90%: still Nearly used
      expect(fake.shown, hasLength(1));

      await spend(20000); // 110%: the next line
      expect(fake.shown, hasLength(2));
      expect(fake.shown.last.title, 'Over budget in Food and shopping');
      expect(fake.shown.last.id, fake.shown.first.id, reason: 'replaces the earlier one');

      await spend(1000);
      expect(fake.shown, hasLength(2));
      expect(fake.asks, 0, reason: 'never asks for permission itself');
    });

    test(
      'editing an entry that already crossed the line warns again only if it goes further',
      () async {
        await warnOn();
        await spend(70000);
        await spend(15000); // 85%: Nearly used, warned once
        expect(fake.shown, hasLength(1));
        final repo = container.read(transactionRepositoryProvider);
        final rows = await repo.watchIn(const PeriodCalculator().month(_now)).first;
        final crossing = rows.firstWhere((t) => t.amount == 15000);

        Future<void> edit(int amount, {String? note}) => withClock(Clock.fixed(_now), () async {
          await repo.update(
            crossing.id,
            TransactionDraft(
              direction: Direction.moneyOut,
              amount: amount,
              categoryId: DefaultIds.food,
              accountId: DefaultIds.mtn,
              occurredAt: _now,
              note: note,
            ),
          );
          final before = rows.firstWhere((t) => t.id == crossing.id);
          await container.read(budgetWarnerProvider).afterSave(crossing.id, previous: before);
        });

        await edit(15000, note: 'only the note changed');
        expect(fake.shown, hasLength(1), reason: 'no new line was crossed');
        await edit(40000); // 110%: over now
        expect(fake.shown, hasLength(2));
        expect(fake.shown.last.title, 'Over budget in Food and shopping');
      },
    );

    test('nothing when the switch is off', () async {
      await spend(95000);
      expect(fake.shown, isEmpty);
    });

    test('nothing for an entry in a budget month that has ended', () async {
      await warnOn();
      await spend(95000, at: DateTime(2026, 10, 20, 9));
      expect(fake.shown, isEmpty);
    });

    test('nothing for a category with no budget', () async {
      await warnOn();
      final id = await withClock(
        Clock.fixed(_now),
        () => container
            .read(transactionRepositoryProvider)
            .add(
              TransactionDraft(
                direction: Direction.moneyOut,
                amount: 500000,
                categoryId: DefaultIds.transport,
                accountId: DefaultIds.mtn,
                occurredAt: _now,
              ),
            ),
      );
      await withClock(Clock.fixed(_now), () => container.read(budgetWarnerProvider).afterSave(id));
      expect(fake.shown, isEmpty);
    });
  });
}
