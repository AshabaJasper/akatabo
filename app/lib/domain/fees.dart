import '../core/time/period.dart';
import '../data/db/app_database.dart';

/// Fees and tax for a set of entries, split three ways (DESIGN_SYSTEM.md "Fees and tax", and
/// owner decision 1 in PLAN.md).
///
/// A fee on a transfer to a Cash account is "Withdrawing cash"; every other fee is "Sending
/// money". All tax, from any entry, is "Tax". Income carries no fee here, because it is not
/// money out, so it is not counted at all.
class FeeSplit {
  const FeeSplit({
    required this.sending,
    required this.sendingCount,
    required this.withdrawing,
    required this.withdrawingCount,
    required this.tax,
    required this.taxOnWithdrawals,
    required this.byAccount,
  });

  /// Fees on sending money and on everything that is not a cash withdrawal.
  final int sending;
  final int sendingCount;

  /// Fees on transfers into a Cash account.
  final int withdrawing;
  final int withdrawingCount;

  /// All tax on money out and transfers.
  final int tax;

  /// The part of [tax] that came from cash withdrawals.
  final int taxOnWithdrawals;

  /// Fees and tax by the account they were paid from, keyed by account id.
  final Map<String, int> byAccount;

  /// Every fee and all tax. The three parts always add to this.
  int get total => sending + withdrawing + tax;

  /// The row reads "Tax on withdrawals" only while all tax came from withdrawals.
  bool get taxIsAllFromWithdrawals => tax > 0 && taxOnWithdrawals == tax;

  static const empty = FeeSplit(
    sending: 0,
    sendingCount: 0,
    withdrawing: 0,
    withdrawingCount: 0,
    tax: 0,
    taxOnWithdrawals: 0,
    byAccount: {},
  );
}

/// Splits the fees and tax in [rows]. [cashAccountIds] are the accounts of kind Cash, so a
/// transfer into one of them counts as a withdrawal.
FeeSplit feeSplitOf(Iterable<Transaction> rows, {required Set<String> cashAccountIds}) {
  var sending = 0;
  var sendingCount = 0;
  var withdrawing = 0;
  var withdrawingCount = 0;
  var tax = 0;
  var taxOnWithdrawals = 0;
  final byAccount = <String, int>{};

  for (final t in rows) {
    if (t.direction == Direction.moneyIn) continue;
    final toCash = t.direction == Direction.transfer && cashAccountIds.contains(t.toAccountId);
    if (t.fee > 0) {
      if (toCash) {
        withdrawing += t.fee;
        withdrawingCount++;
      } else {
        sending += t.fee;
        sendingCount++;
      }
    }
    tax += t.tax;
    if (toCash) taxOnWithdrawals += t.tax;
    final paid = t.fee + t.tax;
    if (paid > 0) byAccount.update(t.accountId, (v) => v + paid, ifAbsent: () => paid);
  }

  return FeeSplit(
    sending: sending,
    sendingCount: sendingCount,
    withdrawing: withdrawing,
    withdrawingCount: withdrawingCount,
    tax: tax,
    taxOnWithdrawals: taxOnWithdrawals,
    byAccount: byAccount,
  );
}

/// The fee split of each month in [months] (oldest first), for the six-month chart on Fees.
List<FeeSplit> feeSplitsByMonth(
  Iterable<Transaction> rows, {
  required List<Period> months,
  required Set<String> cashAccountIds,
}) => [
  for (final m in months)
    feeSplitOf(rows.where((t) => m.containsDay(t.localDay)), cashAccountIds: cashAccountIds),
];
