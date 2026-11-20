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

/// Each account's balance: what the person said was in it ("What is in it today", at
/// `balanceAt`) plus every entry dated from that moment on. Entries dated earlier were already
/// in that amount, so a back-dated entry is not counted twice. An account whose balance was
/// never set has none: the default accounts start that way, so no made-up figure is shown.
class Balances {
  const Balances({
    required this.byAccount,
    required this.total,
    required this.leftOut,
    required this.notSet,
  });

  /// Balance by account id, for every account given whose balance is set.
  final Map<String, int> byAccount;

  /// The sum of the balances of set accounts counted in the person's totals.
  final int total;

  /// Accounts with a set balance switched off from the totals, in the order given.
  final List<Account> leftOut;

  /// Accounts whose balance was never set, in the order given. They are not in [total].
  final List<Account> notSet;
}

Balances balancesOf(List<Account> accounts, Iterable<Transaction> rows) {
  final since = {
    for (final a in accounts)
      if (a.balanceAt != null) a.id: a.balanceAt!,
  };
  final byAccount = {
    for (final a in accounts)
      if (a.balanceAt != null) a.id: a.openingBalance,
  };
  bool counts(String id, Transaction t) =>
      since.containsKey(id) && !t.occurredAt.isBefore(since[id]!);
  for (final t in rows) {
    if (counts(t.accountId, t)) {
      byAccount[t.accountId] = byAccount[t.accountId]! + balanceChangeOf(t, t.accountId);
    }
    final to = t.toAccountId;
    if (t.direction == Direction.transfer && to != null && to != t.accountId && counts(to, t)) {
      byAccount[to] = byAccount[to]! + t.amount;
    }
  }
  var total = 0;
  for (final a in accounts) {
    if (a.countInTotals && byAccount.containsKey(a.id)) total += byAccount[a.id]!;
  }
  return Balances(
    byAccount: byAccount,
    total: total,
    leftOut: [
      for (final a in accounts)
        if (!a.countInTotals && byAccount.containsKey(a.id)) a,
    ],
    notSet: [
      for (final a in accounts)
        if (a.balanceAt == null) a,
    ],
  );
}
