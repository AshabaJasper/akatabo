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
}
