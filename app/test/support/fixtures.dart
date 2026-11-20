import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';

/// Test rows, built the way the database would store them. [day] is the local day as
/// yyyymmdd, and it is derived from [at] when not given.
Transaction txRow({
  String id = 'tx',
  Direction direction = Direction.moneyOut,
  int amount = 10000,
  String description = '',
  String? categoryId = DefaultIds.food,
  String accountId = DefaultIds.mtn,
  String? toAccountId,
  int fee = 0,
  int tax = 0,
  String? note,
  DateTime? at,
  int? day,
  bool categoryWasCorrected = false,
  String? regularPaymentId,
}) {
  final when = at ?? DateTime(2026, 11, 19, 9, 14);
  return Transaction(
    id: id,
    createdAt: when,
    updatedAt: when,
    direction: direction,
    amount: amount,
    description: description,
    payeeKey: description.toLowerCase(),
    categoryId: direction == Direction.transfer ? null : categoryId,
    accountId: accountId,
    toAccountId: toAccountId,
    fee: fee,
    tax: tax,
    note: note,
    occurredAt: when,
    localDay: day ?? when.year * 10000 + when.month * 100 + when.day,
    categoryWasCorrected: categoryWasCorrected,
    flaggedUnusual: false,
    flagDismissed: false,
    regularPaymentId: regularPaymentId,
  );
}

Category categoryRow({
  required String id,
  required String name,
  String iconKey = 'basket',
  String colourToken = 'cat-green',
  CategoryKind kind = CategoryKind.spending,
  bool isSystem = false,
  int? monthlyBudget,
  bool budgetCarriesOver = false,
  int budgetWarnAt = 80,
  int? budgetSince,
}) {
  final now = DateTime(2026, 11);
  return Category(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    iconKey: iconKey,
    colourToken: colourToken,
    kind: kind,
    sortOrder: 0,
    hidden: false,
    monthlyBudget: monthlyBudget,
    budgetCarriesOver: budgetCarriesOver,
    budgetWarnAt: budgetWarnAt,
    budgetSince: budgetSince,
    isSystem: isSystem,
  );
}

Account accountRow({
  required String id,
  required String name,
  String colourToken = 'acct-mtn',
  bool isDefault = false,
  AccountKind kind = AccountKind.mtn,
  bool enabled = true,
  // Mobile money asks for the fee on Add, as the default MTN MoMo does.
  bool askFeeEachTime = true,
  bool countInTotals = true,
  int openingBalance = 0,
}) {
  final now = DateTime(2026, 11);
  return Account(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    kind: kind,
    colourToken: colourToken,
    openingBalance: openingBalance,
    askFeeEachTime: askFeeEachTime,
    countInTotals: countInTotals,
    enabled: enabled,
    isDefault: isDefault,
    sortOrder: 0,
  );
}

RegularPayment regularRow({
  String id = 'reg',
  String label = 'Data bundle',
  int typicalAmount = 10000,
  int? amountLow,
  int? amountHigh,
  required int nextDueOn,
  int intervalDays = 7,
  bool dismissed = false,
}) {
  final now = DateTime(2026, 11);
  return RegularPayment(
    id: id,
    createdAt: now,
    updatedAt: now,
    label: label,
    categoryId: DefaultIds.bills,
    payeeKey: label.toLowerCase(),
    typicalAmount: typicalAmount,
    amountLow: amountLow ?? typicalAmount,
    amountHigh: amountHigh ?? typicalAmount,
    intervalDays: intervalDays,
    nextDueOn: nextDueOn,
    timesSeen: 0,
    source: RegularSource.manual,
    remind: false,
    dismissed: dismissed,
  );
}
