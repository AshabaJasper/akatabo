import '../data/db/app_database.dart';

/// What is in each account today, and the total the person counts as theirs.
///
/// Pure Dart: no Flutter, no database queries.
///
/// "Count it in my totals" on New account applies here and only here. Money out, money in,
/// fees, budgets and the forecast count every entry whatever its account, so spending from
/// an account held for someone else never drops out of the spending figures unseen.

/// How one entry changes [accountId]'s balance. Money out takes the amount, fee and tax from
/// the account paid from; money in adds the amount to the account paid into; a transfer takes
/// the amount, fee and tax from the account it left and adds the amount to the one it reached.
int balanceChangeOf(Transaction t, String accountId) {
  var change = 0;
  if (t.accountId == accountId) {
    change += switch (t.direction) {
      Direction.moneyIn => t.amount,
      Direction.moneyOut || Direction.transfer => -(t.amount + t.fee + t.tax),
    };
  }
  if (t.direction == Direction.transfer && t.toAccountId == accountId) change += t.amount;
  return change;
}

/// Each account's balance: its opening balance ("What is in it today" when it was added) plus
/// every change since.
class Balances {
  const Balances({required this.byAccount, required this.total, required this.leftOut});

  /// Balance by account id, for every account given.
  final Map<String, int> byAccount;

  /// The sum of the balances of accounts counted in the person's totals.
  final int total;

  /// Accounts switched off from the totals, in the order given.
  final List<Account> leftOut;
}

Balances balancesOf(List<Account> accounts, Iterable<Transaction> rows) {
  final byAccount = {for (final a in accounts) a.id: a.openingBalance};
  for (final t in rows) {
    if (byAccount.containsKey(t.accountId)) {
      byAccount[t.accountId] = byAccount[t.accountId]! + balanceChangeOf(t, t.accountId);
    }
    final to = t.toAccountId;
    if (t.direction == Direction.transfer && to != null && to != t.accountId) {
      if (byAccount.containsKey(to)) byAccount[to] = byAccount[to]! + t.amount;
    }
  }
  var total = 0;
  for (final a in accounts) {
    if (a.countInTotals) total += byAccount[a.id]!;
  }
  return Balances(
    byAccount: byAccount,
    total: total,
    leftOut: [
      for (final a in accounts)
        if (!a.countInTotals) a,
    ],
  );
}
