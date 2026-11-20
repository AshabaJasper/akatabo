import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/backup_settings.dart';
import 'package:akatabo/services/backup/restore_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _tx(String id, int day, {int stamp = 1}) => {
  'id': id,
  'localDay': day,
  'updatedAt': stamp,
};

BackupTables _t({
  List<Map<String, Object?>> tx = const [],
  List<Map<String, Object?>> categories = const [],
  List<Map<String, Object?>> settings = const [],
}) => {
  'accounts': [],
  'categories': [...categories],
  'regularPayments': [],
  'transactions': [...tx],
  'settings': [...settings],
  'forecastSnapshots': [],
};

void main() {
  // The drawn case, small: the backup runs 1 March to 12 November; the phone has entries
  // from 1 October to 19 November, some of them not in the backup.
  final backup = _t(
    tx: [
      _tx('old1', 20260301),
      _tx('old2', 20260915),
      _tx('both', 20261005, stamp: 50), // changed later in the backup
      _tx('same', 20261010, stamp: 10),
      _tx('mineNewer', 20261012, stamp: 10),
      _tx('end', 20261112),
    ],
    categories: [
      {'id': 'cat.food', 'monthlyBudget': 300000, 'isSystem': false, 'updatedAt': 1},
      {'id': 'cat.rent', 'monthlyBudget': null, 'isSystem': false, 'updatedAt': 1},
      {'id': 'cat.fees', 'monthlyBudget': null, 'isSystem': true, 'updatedAt': 1},
    ],
  );
  final phone = _t(
    tx: [
      _tx('both', 20261005, stamp: 20),
      _tx('same', 20261010, stamp: 10),
      _tx('mineNewer', 20261012, stamp: 99),
      _tx('end', 20261112),
      _tx('new1', 20261113),
      _tx('new2', 20261119),
    ],
    categories: [
      {'id': 'cat.food', 'monthlyBudget': null, 'isSystem': false, 'updatedAt': 1},
    ],
  );

  group('preview', () {
    final p = RestorePlanner(backup: backup, phone: phone).preview();

    test('what is in the backup', () {
      expect(p.backupTransactions, 6);
      expect(p.backupCategories, 2, reason: 'Fees and tax is left out');
      expect(p.backupBudgets, 1);
      expect((p.backupFirstDay, p.backupLastDay), (20260301, 20261112));
    });

    test('how it overlaps with this phone', () {
      expect(p.phoneTransactions, 6);
      expect((p.phoneFirstDay, p.phoneLastDay), (20261005, 20261119));
      expect(p.phoneOnly, 2);
      expect((p.phoneOnlyFirstDay, p.phoneOnlyLastDay), (20261113, 20261119));
      expect(p.lostByReplacing, 2);
    });

    test('what each choice would do', () {
      expect(p.toAdd, 2);
      expect(p.toUpdate, 1);
      expect(p.phoneNewer, 1);
      expect(p.otherChanges, 2, reason: 'cat.rent and cat.fees are new; cat.food is as old');
      expect(p.restoreCount(RestoreMode.addMissing), 2);
      expect(p.restoreCount(RestoreMode.replaceAll), 6);
      expect(p.addMissingChangesSomething, isTrue);
    });
  });

  group('add what is missing', () {
    final plan = RestorePlanner(backup: backup, phone: phone).plan(RestoreMode.addMissing);
    Set<String> ids(String t) => {for (final r in plan.upserts[t]!) '${r['id']}'};

    test('adds rows not on the phone and the newer copy of a shared row', () {
      expect(ids('transactions'), {'old1', 'old2', 'both'});
    });

    test('keeps the phone copy when it is newer or the same age', () {
      expect(ids('transactions'), isNot(contains('mineNewer')));
      expect(ids('transactions'), isNot(contains('same')));
    });

    test('deletes nothing', () {
      expect(plan.deletes.values.every((d) => d.isEmpty), isTrue);
    });

    test('the same id with the newer updatedAt wins either way round', () {
      final a = _t(tx: [_tx('x', 20261101, stamp: 5)]);
      final b = _t(tx: [_tx('x', 20261101, stamp: 6)]);
      expect(
        RestorePlanner(backup: b, phone: a).plan(RestoreMode.addMissing).upserts['transactions'],
        hasLength(1),
      );
      expect(
        RestorePlanner(backup: a, phone: b).plan(RestoreMode.addMissing).upserts['transactions'],
        isEmpty,
      );
    });
  });

  group('replace everything', () {
    final plan = RestorePlanner(backup: backup, phone: phone).plan(RestoreMode.replaceAll);

    test('writes every backup row and deletes the rows only on this phone', () {
      expect(plan.upserts['transactions'], hasLength(6));
      expect(plan.deletes['transactions'], unorderedEquals(['new1', 'new2']));
      expect(plan.deletes['categories'], isEmpty);
    });
  });

  group('settings that stay with the phone', () {
    final b = _t(
      settings: [
        {'key': 'backup.lastAt', 'value': '1', 'updatedAt': 99},
        {'key': 'lock.enabled', 'value': '1', 'updatedAt': 99},
        {'key': 'general.monthStartsOn', 'value': '25', 'updatedAt': 99},
      ],
    );
    final p = _t(
      settings: [
        {'key': 'backup.weekly', 'value': '1', 'updatedAt': 1},
        {'key': 'app.onboardingDone', 'value': '1', 'updatedAt': 1},
        {'key': 'smart.suggestCategory', 'value': '0', 'updatedAt': 1},
      ],
    );
    final planner = RestorePlanner(backup: b, phone: p, keepOnPhone: isLocalOnlySetting);

    test('are never taken from the file', () {
      for (final mode in RestoreMode.values) {
        final keys = [for (final r in planner.plan(mode).upserts['settings']!) r['key']];
        expect(keys, ['general.monthStartsOn'], reason: mode.name);
      }
    });

    test('are never removed by replacing', () {
      expect(planner.plan(RestoreMode.replaceAll).deletes['settings'], ['smart.suggestCategory']);
    });
  });

  test('saved forecasts match by month and day, by creation time', () {
    final snap = {'periodStart': 20261101, 'takenOn': 20261110, 'createdAt': 5};
    final planner = RestorePlanner(
      backup: _t()..['forecastSnapshots'] = [snap],
      phone: _t()
        ..['forecastSnapshots'] = [
          {...snap, 'createdAt': 9},
        ],
    );
    expect(planner.plan(RestoreMode.addMissing).upserts['forecastSnapshots'], isEmpty);
    expect(planner.plan(RestoreMode.replaceAll).deletes['forecastSnapshots'], isEmpty);
  });

  test('a backup equal to the phone changes nothing when adding', () {
    final planner = RestorePlanner(backup: phone, phone: phone);
    expect(planner.plan(RestoreMode.addMissing).isEmpty, isTrue);
    expect(planner.preview().addMissingChangesSomething, isFalse);
    expect(planner.preview().phoneOnly, 0);
  });
}
