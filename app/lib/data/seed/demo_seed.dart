import '../db/tables.dart';
import '../repositories/repositories.dart';
import 'default_data.dart';

/// Demo entries for trying the app on a device or in screenshots. Synthetic: none of these
/// figures are the person's, and none are real payees.
///
/// Only used when the app is built with `--dart-define=AKATABO_DEMO=true`, and only into an
/// empty database, so it never adds to a person's own records.
class _Demo {
  const _Demo(
    this.daysAgo,
    this.hour,
    this.minute,
    this.words,
    this.amount, {
    this.category = DefaultIds.food,
    this.account = DefaultIds.mtn,
    this.direction = Direction.moneyOut,
    this.fee = 0,
    this.tax = 0,
    this.toAccount,
  });

  final int daysAgo;
  final int hour;
  final int minute;
  final String words;
  final int amount;
  final String category;
  final String account;
  final Direction direction;
  final int fee;
  final int tax;
  final String? toAccount;
}

const _entries = [
  _Demo(0, 9, 14, 'Groceries, Nakasero market', 45000, fee: 1000),
  _Demo(0, 8, 2, 'Boda to town', 8000, category: DefaultIds.transport, account: DefaultIds.cash),
  _Demo(
    1,
    19,
    40,
    'Yaka electricity',
    30000,
    category: DefaultIds.bills,
    account: DefaultIds.airtel,
  ),
  _Demo(
    2,
    14,
    30,
    'Payment from client',
    250000,
    category: DefaultIds.business,
    account: DefaultIds.bank,
    direction: Direction.moneyIn,
  ),
  _Demo(2, 13, 5, 'Lunch at work', 9000, account: DefaultIds.cash),
  _Demo(
    3,
    10,
    20,
    'Cash withdrawal',
    25000,
    category: DefaultIds.fees,
    direction: Direction.transfer,
    fee: 1500,
    tax: 900,
    toAccount: DefaultIds.cash,
  ),
  _Demo(
    4,
    16,
    11,
    'School fees, term two',
    350000,
    category: DefaultIds.school,
    account: DefaultIds.bank,
  ),
  _Demo(5, 12, 45, 'Clinic visit', 40000, category: DefaultIds.health),
  _Demo(
    6,
    7,
    30,
    'Maama Joan, rent share',
    120000,
    category: DefaultIds.family,
    account: DefaultIds.airtel,
  ),
  _Demo(7, 18, 22, 'Matooke and beans', 22000, account: DefaultIds.cash),
  _Demo(8, 9, 3, 'Boda home', 6000, category: DefaultIds.transport, account: DefaultIds.cash),
  _Demo(9, 15, 50, 'Airtime', 20000, category: DefaultIds.bills),
  _Demo(
    10,
    11,
    0,
    'Salary, October',
    1200000,
    category: DefaultIds.salary,
    account: DefaultIds.bank,
    direction: Direction.moneyIn,
  ),
  _Demo(11, 17, 30, 'Pharmacy', 18000, category: DefaultIds.health),
  _Demo(12, 13, 10, 'Fuel for the bodaboda', 35000, category: DefaultIds.transport),
  _Demo(13, 8, 40, 'Shoes for Ruth', 85000, category: DefaultIds.family),
  _Demo(14, 19, 5, 'Dinner out', 48000),
  _Demo(16, 10, 0, 'Stationery', 15000, category: DefaultIds.school, account: DefaultIds.cash),
  _Demo(18, 12, 0, 'Water bill', 12000, category: DefaultIds.bills, account: DefaultIds.cash),
  _Demo(20, 9, 50, 'Groceries, Owino', 62000, fee: 500),
  _Demo(
    22,
    16,
    35,
    'Gift money back',
    40000,
    category: DefaultIds.refunds,
    direction: Direction.moneyIn,
  ),
  _Demo(25, 14, 0, 'Internet', 80000, category: DefaultIds.bills, account: DefaultIds.airtel),
  _Demo(
    28,
    10,
    15,
    'Transfer to bank',
    300000,
    category: DefaultIds.fees,
    direction: Direction.transfer,
    fee: 2000,
    toAccount: DefaultIds.bank,
  ),
];

/// Inserts [_entries] relative to [now]. Does nothing if any entry already exists.
Future<void> insertDemoData(
  TransactionRepository repo, {
  required DateTime now,
  required bool isEmpty,
}) async {
  if (!isEmpty) return;
  final today = DateTime(now.year, now.month, now.day);
  for (final e in _entries) {
    final when = DateTime(today.year, today.month, today.day - e.daysAgo, e.hour, e.minute);
    if (when.isAfter(now)) continue;
    await repo.add(
      TransactionDraft(
        direction: e.direction,
        amount: e.amount,
        description: e.words,
        categoryId: e.direction == Direction.transfer ? null : e.category,
        accountId: e.account,
        toAccountId: e.toAccount,
        fee: e.fee,
        tax: e.tax,
        occurredAt: when,
      ),
    );
  }
}
