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
  );
}

Category categoryRow({
  required String id,
  required String name,
  String iconKey = 'basket',
  String colourToken = 'cat-green',
  CategoryKind kind = CategoryKind.spending,
  bool isSystem = false,
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
    budgetCarriesOver: false,
    budgetWarnAt: 80,
    isSystem: isSystem,
  );
}

Account accountRow({
  required String id,
  required String name,
  String colourToken = 'acct-mtn',
  bool isDefault = false,
}) {
  final now = DateTime(2026, 11);
  return Account(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    kind: AccountKind.mtn,
    colourToken: colourToken,
    openingBalance: 0,
    askFeeEachTime: false,
    countInTotals: true,
    enabled: true,
    isDefault: isDefault,
    sortOrder: 0,
  );
}
