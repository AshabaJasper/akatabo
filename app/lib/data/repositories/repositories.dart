import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/period.dart';
import '../../smart/text_normaliser.dart';
import '../db/app_database.dart';
import '../settings/setting_keys.dart';

const _uuid = Uuid();

/// What the person entered on Add, before it is stored.
class TransactionDraft {
  const TransactionDraft({
    required this.direction,
    required this.amount,
    required this.accountId,
    required this.occurredAt,
    this.description = '',
    this.categoryId,
    this.toAccountId,
    this.fee = 0,
    this.tax = 0,
    this.note,
    this.suggestedCategoryId,
    this.suggestionConfidence,
  });

  final Direction direction;
  final int amount;
  final String description;
  final String? categoryId;
  final String accountId;
  final String? toAccountId;
  final int fee;
  final int tax;
  final String? note;
  final DateTime occurredAt;
  final String? suggestedCategoryId;
  final double? suggestionConfidence;

  /// What is wrong with the draft, in words for the person; empty when it can be saved.
  List<String> problems() => [
    if (amount <= 0) 'Enter an amount above zero.',
    if (fee < 0 || tax < 0) 'A fee or tax cannot be below zero.',
    if (direction == Direction.transfer && toAccountId == null) 'Choose where the money went.',
    if (direction == Direction.transfer && toAccountId == accountId)
      'Choose two different accounts.',
    if (direction != Direction.transfer && categoryId == null) 'Choose a category.',
  ];
}

class TransactionRepository {
  TransactionRepository(this._db);
  final AppDatabase _db;

  TransactionsCompanion _companion(TransactionDraft d, {required DateTime now}) {
    final problems = d.problems();
    if (problems.isNotEmpty) throw ArgumentError(problems.join(' '));
    final transfer = d.direction == Direction.transfer;
    return TransactionsCompanion(
      direction: Value(d.direction),
      amount: Value(d.amount),
      description: Value(d.description.trim()),
      payeeKey: Value(payeeKeyOf(d.description)),
      categoryId: Value(transfer ? null : d.categoryId),
      accountId: Value(d.accountId),
      toAccountId: Value(transfer ? d.toAccountId : null),
      fee: Value(d.fee),
      tax: Value(d.tax),
      note: Value(d.note?.trim().isEmpty ?? true ? null : d.note!.trim()),
      occurredAt: Value(d.occurredAt),
      localDay: Value(toLocalDay(d.occurredAt)),
      suggestedCategoryId: Value(d.suggestedCategoryId),
      suggestionConfidence: Value(d.suggestionConfidence),
      categoryWasCorrected: Value(
        d.suggestedCategoryId != null && d.categoryId != d.suggestedCategoryId,
      ),
      updatedAt: Value(now),
    );
  }

  /// Stores a new transaction and returns its id.
  Future<String> add(TransactionDraft draft) async {
    final now = clock.now();
    final id = _uuid.v4();
    await _db
        .into(_db.transactions)
        .insert(_companion(draft, now: now).copyWith(id: Value(id), createdAt: Value(now)));
    return id;
  }

  Future<void> update(String id, TransactionDraft draft) async {
    await (_db.update(
      _db.transactions,
    )..where((t) => t.id.equals(id))).write(_companion(draft, now: clock.now()));
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  Future<Transaction?> byId(String id) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Transactions on days in [period], newest first.
  Stream<List<Transaction>> watchIn(Period period) =>
      (_db.select(_db.transactions)
            ..where(
              (t) =>
                  t.localDay.isBiggerOrEqualValue(period.startDay) &
                  t.localDay.isSmallerThanValue(period.endDay),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .watch();

  Stream<List<Transaction>> watchLatest(int limit) =>
      (_db.select(_db.transactions)
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(limit))
          .watch();

  /// Every transaction, newest first.
  Stream<List<Transaction>> watchAll() =>
      (_db.select(_db.transactions)..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  /// One transaction, or null once it has been deleted.
  Stream<Transaction?> watchById(String id) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(id))).watchSingleOrNull();
}

class CategoryRepository {
  CategoryRepository(this._db);
  final AppDatabase _db;

  /// Categories of one kind in the person's order. Hidden ones are left out unless asked.
  Stream<List<Category>> watch(CategoryKind kind, {bool includeHidden = false}) {
    final q = _db.select(_db.categories)
      ..where((c) => c.kind.equalsValue(kind))
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    if (!includeHidden) q.where((c) => c.hidden.not());
    return q.watch();
  }

  Stream<List<Category>> watchAll() =>
      (_db.select(_db.categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).watch();

  /// Sets or clears a category's monthly budget. [monthlyBudget] null removes the budget.
  Future<void> setBudget(
    String id, {
    required int? monthlyBudget,
    required bool carriesOver,
    required int warnAt,
  }) async {
    final now = clock.now();
    final current = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    // A new budget, or carry-over switched on, starts its clock today; changing the amount
    // or the warn level keeps it, so a long-standing budget keeps carrying.
    final int? since;
    if (monthlyBudget == null) {
      since = null;
    } else if (current?.monthlyBudget == null ||
        (carriesOver && !(current?.budgetCarriesOver ?? false)) ||
        current?.budgetSince == null) {
      since = toLocalDay(now);
    } else {
      since = current!.budgetSince;
    }
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        monthlyBudget: Value(monthlyBudget),
        budgetCarriesOver: Value(carriesOver),
        budgetWarnAt: Value(warnAt),
        budgetSince: Value(since),
        updatedAt: Value(now),
      ),
    );
  }
}

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Stream<List<Account>> watchEnabled() =>
      (_db.select(_db.accounts)
            ..where((a) => a.enabled)
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .watch();

  /// Switches an account on or off. Off accounts stop being offered on Add; past entries keep them.
  Future<void> setEnabled(String id, {required bool enabled}) => (_db.update(
    _db.accounts,
  )..where((a) => a.id.equals(id))).write(AccountsCompanion(enabled: Value(enabled)));

  /// Every account, switched off ones too, so past entries keep their account's name and kind.
  Stream<List<Account>> watchAll() =>
      (_db.select(_db.accounts)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).watch();
}

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  /// Every stored setting by key. Missing keys take their default when decoded.
  Stream<Map<String, String>> watchAll() =>
      _db.select(_db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Stream<T> watch<T>(SettingKey<T> key) => (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key.name))).watchSingleOrNull().map((row) => key.decode(row?.value));

  Future<T> read<T>(SettingKey<T> key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key.name))).getSingleOrNull();
    return key.decode(row?.value);
  }

  Future<void> write<T>(SettingKey<T> key, T value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: key.name, value: key.encode(value), updatedAt: clock.now()),
      );
}

class RegularPaymentRepository {
  RegularPaymentRepository(this._db);
  final AppDatabase _db;

  /// Payments the person has not dismissed, the soonest first.
  Stream<List<RegularPayment>> watchActive() =>
      (_db.select(_db.regularPayments)
            ..where((r) => r.dismissed.not())
            ..orderBy([(r) => OrderingTerm.asc(r.nextDueOn)]))
          .watch();

  /// Adds a payment the person entered. The amount is one typical figure with no range.
  Future<String> add({
    required String label,
    required int amount,
    required int intervalDays,
    required int nextDueOn,
    String? categoryId,
  }) async {
    final now = clock.now();
    final id = _uuid.v4();
    await _db
        .into(_db.regularPayments)
        .insert(
          RegularPaymentsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            label: label.trim(),
            categoryId: Value(categoryId),
            payeeKey: Value(payeeKeyOf(label)),
            typicalAmount: amount,
            amountLow: amount,
            amountHigh: amount,
            intervalDays: intervalDays,
            nextDueOn: nextDueOn,
            source: RegularSource.manual,
          ),
        );
    return id;
  }

  /// Takes a payment off the list. It is kept, so the same payee is not detected again.
  Future<void> dismiss(String id) =>
      (_db.update(_db.regularPayments)..where((r) => r.id.equals(id))).write(
        RegularPaymentsCompanion(dismissed: const Value(true), updatedAt: Value(clock.now())),
      );
}
