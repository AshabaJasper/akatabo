// drift's check() names the column through its own getter; that is how drift builds the SQL.
// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

/// Which way money moved. A transfer moves money between the person's own accounts
/// (a cash withdrawal is one); only its fee and tax count as money out.
enum Direction { moneyOut, moneyIn, transfer }

enum CategoryKind { spending, income }

/// `mtn` and `airtel` are the two default mobile money accounts. An account the person adds
/// as "Mobile" on New account is `mobile`, since the form does not ask for the network.
/// Stored by name, so adding a value needs no schema change.
enum AccountKind { cash, mtn, airtel, bank, other, mobile }

enum RegularSource { detected, manual }

/// Shared columns: a text UUID (or a fixed id for defaults) and change times, so a backup
/// can be merged by id with the newer `updatedAt` winning.
mixin _Synced on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'tx_local_day', columns: {#localDay})
@TableIndex(name: 'tx_category', columns: {#categoryId})
@TableIndex(name: 'tx_payee', columns: {#payeeKey})
class Transactions extends Table with _Synced {
  TextColumn get direction => textEnum<Direction>()();

  /// Whole shillings, always above zero. The direction carries the sign.
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// The description normalised for matching: payee history, regular payments, new payee.
  TextColumn get payeeKey => text().withDefault(const Constant(''))();

  /// Null only for transfers, which have no category.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  @ReferenceName('paidFrom')
  TextColumn get accountId => text().references(Accounts, #id)();

  /// The receiving account of a transfer.
  @ReferenceName('movedTo')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  IntColumn get fee =>
      integer().withDefault(const Constant(0)).check(fee.isBiggerOrEqualValue(0))();
  IntColumn get tax =>
      integer().withDefault(const Constant(0)).check(tax.isBiggerOrEqualValue(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  /// The local calendar day of [occurredAt] as yyyymmdd, written at save time, so period
  /// queries do not depend on the phone's time zone later.
  IntColumn get localDay => integer()();
  TextColumn get suggestedCategoryId => text().nullable()();
  RealColumn get suggestionConfidence => real().nullable()();
  BoolColumn get categoryWasCorrected => boolean().withDefault(const Constant(false))();
  BoolColumn get flaggedUnusual => boolean().withDefault(const Constant(false))();
  BoolColumn get flagDismissed => boolean().withDefault(const Constant(false))();
  TextColumn get regularPaymentId => text().nullable()();

  /// The currency the person paid in, when it was not shillings (e.g. "USD"). Null for
  /// shillings. [amount] is always the shillings, so totals and budgets do not change.
  TextColumn get foreignCurrency => text().nullable()();

  /// The amount in [foreignCurrency], in hundredths of its unit (100.50 USD is 10050).
  IntColumn get foreignAmountMinor => integer().nullable()();

  /// Shillings per one unit of [foreignCurrency], times a million (3,720 is 3720000000).
  IntColumn get rateMicros => integer().nullable()();
}

class Categories extends Table with _Synced {
  TextColumn get name => text()();

  /// A name from the icon table in DESIGN_SYSTEM.md.
  TextColumn get iconKey => text()();

  /// A `cat-` colour token name.
  TextColumn get colourToken => text()();
  TextColumn get kind => textEnum<CategoryKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get monthlyBudget => integer().nullable()();
  BoolColumn get budgetCarriesOver => boolean().withDefault(const Constant(false))();

  /// The "Nearly used" level, as a whole percent of the budget.
  IntColumn get budgetWarnAt => integer().withDefault(const Constant(80))();

  /// The local day (yyyymmdd) the budget started, or carry-over was switched on. Carry-over
  /// counts only once the budget covered all of last month. Null with no budget. Schema v2.
  IntColumn get budgetSince => integer().nullable()();

  /// Fees and tax: its totals are built from the fee and tax fields, not chosen on Add.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
}

class Accounts extends Table with _Synced {
  TextColumn get name => text()();
  TextColumn get kind => textEnum<AccountKind>()();

  /// An `acct-` or `cat-` colour token name.
  TextColumn get colourToken => text()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();

  /// When [openingBalance] was what was in the account: entries from this moment on change
  /// its balance; earlier ones were already in it. Null until the person says what is in it,
  /// so the default accounts never show a made-up balance. Schema v3.
  DateTimeColumn get balanceAt => dateTime().nullable()();
  BoolColumn get askFeeEachTime => boolean().withDefault(const Constant(false))();
  BoolColumn get countInTotals => boolean().withDefault(const Constant(true))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class RegularPayments extends Table with _Synced {
  TextColumn get label => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get payeeKey => text().withDefault(const Constant(''))();
  IntColumn get typicalAmount => integer()();
  IntColumn get amountLow => integer()();
  IntColumn get amountHigh => integer()();
  IntColumn get intervalDays => integer()();

  /// yyyymmdd.
  IntColumn get nextDueOn => integer()();
  IntColumn get timesSeen => integer().withDefault(const Constant(0))();
  TextColumn get source => textEnum<RegularSource>()();
  BoolColumn get remind => boolean().withDefault(const Constant(false))();

  /// A wrong detection the person removed. Kept so it is not detected again.
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The month-end forecast as it was shown on a day, so "How close it has been" reports what
/// was really forecast, not a recalculation.
class ForecastSnapshots extends Table {
  /// First day of the month the forecast is for, yyyymmdd.
  IntColumn get periodStart => integer()();

  /// The day the forecast was shown, yyyymmdd.
  IntColumn get takenOn => integer()();
  IntColumn get point => integer()();
  IntColumn get low => integer()();
  IntColumn get high => integer()();
  IntColumn get spentSoFar => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {periodStart, takenOn};
}

/// How often a goal reminds the person to add to it. Stored by name.
enum GoalRemind { off, weekly, monthly }

/// Something the person is saving toward. The money saved is not in this row: it is the sum
/// of the goal's [GoalMoves], so it can never drift from the moves that made it. Schema v5.
class Goals extends Table with _Synced {
  TextColumn get name => text()();

  /// A name from the icon table in DESIGN_SYSTEM.md; `wallet` is the "Savings" icon.
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();

  /// A `cat-` colour token name.
  TextColumn get colourToken => text()();

  /// Whole shillings to reach, above zero.
  IntColumn get target => integer().check(target.isBiggerThanValue(0))();

  /// The local day (yyyymmdd) the person wants to reach it by. Null with no date.
  IntColumn get targetDay => integer().nullable()();
  TextColumn get remindEvery => textEnum<GoalRemind>().withDefault(Constant(GoalRemind.off.name))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// When the saved amount first reached [target]. Cleared if money is taken out below it.
  DateTimeColumn get reachedAt => dateTime().nullable()();

  /// When the person put the goal away. Its moves stay, so its money stays set aside until
  /// it is taken out.
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

/// Money set aside for a goal inside one account, or taken back out. Not a transaction: the
/// money does not leave the account, so totals, budgets and the forecast never see it. The
/// account's free-to-spend figure is its balance less what its moves have set aside. Schema v5.
@TableIndex(name: 'goal_move_goal', columns: {#goalId})
@TableIndex(name: 'goal_move_account', columns: {#accountId})
class GoalMoves extends Table with _Synced {
  TextColumn get goalId => text().references(Goals, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Whole shillings, never zero: above zero sets money aside, below zero takes it out.
  IntColumn get amount => integer().check(amount.equals(0).not())();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  /// The local calendar day of [occurredAt] as yyyymmdd, written at save time.
  IntColumn get localDay => integer()();
}
