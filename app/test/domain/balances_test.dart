import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/balances.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final mtn = accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', openingBalance: 200000);
  final cash = accountRow(id: DefaultIds.cash, name: 'Cash', kind: AccountKind.cash);
  final held = accountRow(
    id: 'held',
    name: 'Savings for Mum',
    openingBalance: 500000,
    countInTotals: false,
  );

  final rows = [
    txRow(id: 'a', amount: 45000, fee: 500, tax: 225), // money out from MTN
    txRow(id: 'b', direction: Direction.moneyIn, amount: 250000, accountId: DefaultIds.cash),
    txRow(
      id: 'c',
      direction: Direction.transfer,
      amount: 100000,
      fee: 2000,
      toAccountId: DefaultIds.cash,
    ),
    txRow(id: 'd', amount: 30000, accountId: 'held'), // spent from the money held for Mum
  ];

  test('each balance is what it started with plus every change since', () {
    final b = balancesOf([mtn, cash, held], rows);
    expect(b.byAccount[DefaultIds.mtn], 200000 - 45725 - 102000);
    expect(b.byAccount[DefaultIds.cash], 250000 + 100000);
    expect(b.byAccount['held'], 500000 - 30000);
  });

  test('"Count it in my totals" switched off leaves the account out of the total only', () {
    final counted = balancesOf([mtn, cash, held.copyWith(countInTotals: true)], rows);
    final notCounted = balancesOf([mtn, cash, held], rows);
    expect(counted.total - notCounted.total, 470000);
    expect(notCounted.total, (200000 - 45725 - 102000) + 350000);
    expect(notCounted.leftOut.map((a) => a.name), ['Savings for Mum']);
    expect(counted.leftOut, isEmpty);
  });

  test('money out keeps every entry, whatever the account counts in', () {
    // The flag is applied to balances only: spending from the held account still counts.
    expect(totalsOf(rows).moneyOut, 45725 + 2000 + 30000);
  });

  test('a transfer moves money between accounts without changing the total, less its fee', () {
    final before = balancesOf([mtn, cash], const []);
    final after = balancesOf([mtn, cash], [rows[2]]);
    expect(after.total, before.total - 2000);
  });

  group('when the balance was set', () {
    final set = DateTime(2026, 11, 10, 12);
    final savings = accountRow(id: 'sav', name: 'Savings', openingBalance: 50000, balanceAt: set);

    test('an entry dated before the balance was set was already in it', () {
      final before = txRow(id: 'x', amount: 5000, accountId: 'sav', at: DateTime(2026, 11, 9));
      expect(balancesOf([savings], [before]).byAccount['sav'], 50000);
    });

    test('an entry dated from that moment on changes it', () {
      final after = txRow(id: 'y', amount: 5000, accountId: 'sav', at: DateTime(2026, 11, 11));
      final atSet = txRow(id: 'z', amount: 1000, accountId: 'sav', at: set);
      expect(balancesOf([savings], [after, atSet]).byAccount['sav'], 44000);
    });

    test('a transfer dated before only changes the account already set then', () {
      final move = txRow(
        id: 't',
        direction: Direction.transfer,
        amount: 20000,
        fee: 500,
        toAccountId: 'sav',
        at: DateTime(2026, 11, 9),
      );
      final b = balancesOf([mtn, savings], [move]);
      expect(b.byAccount[DefaultIds.mtn], 200000 - 20500);
      expect(b.byAccount['sav'], 50000);
    });

    test('an account never set has no balance and stays out of the total', () {
      final unset = accountRow(id: DefaultIds.airtel, name: 'Airtel Money', unset: true);
      final spent = txRow(id: 'u', amount: 45000, accountId: DefaultIds.airtel);
      final b = balancesOf([cash, unset], [spent]);
      expect(b.byAccount.containsKey(DefaultIds.airtel), isFalse);
      expect(b.notSet.map((a) => a.name), ['Airtel Money']);
      expect(b.total, 0, reason: 'Cash holds 0; the unset account adds nothing');
      expect(b.leftOut, isEmpty);
    });
  });
}
