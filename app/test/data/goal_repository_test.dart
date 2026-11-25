import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GoalRepository goals;
  final now = DateTime(2026, 11, 24, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    goals = GoalRepository(db);
  });
  tearDown(() => db.close());

  /// Runs [body] with the clock fixed at [now], so every saved time is known.
  Future<void> at(Future<void> Function() body) => withClock(Clock.fixed(now), body);

  Future<String> addGoal({String name = 'School fees', int target = 100000}) =>
      goals.add(name: name, target: target, colourToken: 'cat-teal');

  group('add', () {
    test('trims the name and lists the goal after the ones before it', () async {
      await at(() async {
        await addGoal(name: '  School fees  ');
        await addGoal(name: 'Phone');
        final list = await goals.watchActive().first;
        expect(list.map((g) => g.name), ['School fees', 'Phone']);
        expect(list.map((g) => g.iconKey), everyElement('wallet'));
      });
    });

    test('refuses an empty name and a target that is not above zero', () async {
      await at(() async {
        await expectLater(addGoal(name: '   '), throwsArgumentError);
        await expectLater(addGoal(target: 0), throwsArgumentError);
        expect(await goals.watchActive().first, isEmpty);
      });
    });

    test('refuses a date before today, and accepts today', () async {
      await at(() async {
        await expectLater(
          goals.add(name: 'Old', target: 100000, colourToken: 'cat-teal', targetDay: 20261123),
          throwsArgumentError,
        );
        await goals.add(
          name: 'Today',
          target: 100000,
          colourToken: 'cat-teal',
          targetDay: 20261124,
        );
        expect(await goals.watchActive().first, hasLength(1));
      });
    });
  });

  group('addMove', () {
    test('sets money aside inside an account and reports the milestones crossed', () async {
      await at(() async {
        final id = await addGoal();
        final crossed = await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 30000);
        expect(crossed, [25]);
        expect(await goals.savedFor(id), 30000);
        final moves = await goals.watchMoves(id).first;
        expect(moves.single.localDay, 20261124);
        expect(moves.single.accountId, DefaultIds.mtn);
      });
    });

    test(
      'sets the reached date when the target is met, and clears it when money comes out',
      () async {
        await at(() async {
          final id = await addGoal(target: 50000);
          await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 50000);
          expect((await goals.watchById(id).first)!.reachedAt, now);

          await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: -10000);
          expect((await goals.watchById(id).first)!.reachedAt, isNull);
        });
      },
    );

    test('refuses taking out more than is saved, and changes nothing', () async {
      await at(() async {
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 20000);
        await expectLater(
          goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: -20001),
          throwsArgumentError,
        );
        expect(await goals.savedFor(id), 20000);
        expect(await goals.watchMoves(id).first, hasLength(1));
      });
    });

    test('refuses a zero move, an unknown goal and an unknown account', () async {
      await at(() async {
        final id = await addGoal();
        await expectLater(
          goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 0),
          throwsArgumentError,
        );
        await expectLater(
          goals.addMove(goalId: 'nope', accountId: DefaultIds.mtn, amount: 100),
          throwsStateError,
        );
        await expectLater(
          goals.addMove(goalId: id, accountId: 'acct.nope', amount: 100),
          throwsStateError,
        );
      });
    });

    test('refuses taking out of an account the goal has nothing in, and changes nothing', () async {
      await at(() async {
        final bank = await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank);
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 10000);
        await expectLater(
          goals.addMove(goalId: id, accountId: bank, amount: -5000),
          throwsArgumentError,
        );
        expect(await goals.savedFor(id), 10000);
        expect(await goals.watchMoves(id).first, hasLength(1));
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: -5000);
        expect(await goals.savedFor(id), 5000);
      });
    });

    test('refuses adding to an archived goal, but still lets the money come out', () async {
      await at(() async {
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 20000);
        await goals.archive(id);
        await expectLater(
          goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 100),
          throwsStateError,
        );
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: -20000);
        expect(await goals.savedFor(id), 0);
      });
    });
  });

  group('update', () {
    test('a lower target that the saved amount now meets sets the reached date', () async {
      await at(() async {
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 60000);
        expect((await goals.watchById(id).first)!.reachedAt, isNull);
        await goals.update(id, name: 'School fees', target: 50000, colourToken: 'cat-teal');
        expect((await goals.watchById(id).first)!.reachedAt, now);
      });
    });
  });

  group('archive and delete', () {
    test('an archived goal leaves the active list, and comes back with unarchive', () async {
      await at(() async {
        final id = await addGoal();
        await goals.archive(id);
        expect(await goals.watchActive().first, isEmpty);
        await goals.unarchive(id);
        expect(await goals.watchActive().first, hasLength(1));
      });
    });

    test('a goal with any moves cannot be deleted, even if its money was taken back out', () async {
      await at(() async {
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: 20000);
        await goals.addMove(goalId: id, accountId: DefaultIds.mtn, amount: -20000);
        await expectLater(goals.delete(id), throwsStateError);
        expect(await goals.watchActive().first, hasLength(1));
      });
    });

    test('a goal with no moves can be deleted', () async {
      await at(() async {
        final id = await addGoal();
        await goals.delete(id);
        expect(await goals.watchActive().first, isEmpty);
      });
    });
  });

  group('the account behind the money', () {
    test('an account with money set aside in it cannot be deleted', () async {
      await at(() async {
        final bank = await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank);
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: bank, amount: 20000);
        expect(await AccountRepository(db).usedBy(bank), 1);
        await expectLater(AccountRepository(db).delete(bank), throwsStateError);
      });
    });

    test('counts goal money and entries separately', () async {
      await at(() async {
        final bank = await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank);
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: bank, amount: 20000);
        expect(await AccountRepository(db).entriesIn(bank), 0);
        expect(await AccountRepository(db).goalMovesIn(bank), 1);
      });
    });

    test('counts each goal once, however many moves it has in the account', () async {
      await at(() async {
        final bank = await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank);
        final id = await addGoal();
        await goals.addMove(goalId: id, accountId: bank, amount: 20000);
        await goals.addMove(goalId: id, accountId: bank, amount: 10000);
        await goals.addMove(goalId: id, accountId: bank, amount: -30000);
        final other = await addGoal(name: 'Phone');
        await goals.addMove(goalId: other, accountId: DefaultIds.mtn, amount: 5000);
        expect(await AccountRepository(db).goalMovesIn(bank), 3);
        expect(await AccountRepository(db).goalsIn(bank), 1);
        expect(await AccountRepository(db).goalsIn(DefaultIds.mtn), 1);
      });
    });

    test('an account with no entries and no goal money can still be deleted', () async {
      await at(() async {
        final bank = await AccountRepository(db).add(name: 'Stanbic', kind: AccountKind.bank);
        await AccountRepository(db).delete(bank);
        expect(await AccountRepository(db).usedBy(bank), 0);
      });
    });
  });
}
