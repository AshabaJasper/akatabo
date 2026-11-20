import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/period.dart';
import '../../smart/text_normaliser.dart';
import '../db/app_database.dart';
import '../seed/default_data.dart';
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

/// A category name that another category already has.
class CategoryNameTaken implements Exception {
  const CategoryNameTaken(this.name);
  final String name;

  @override
  String toString() => 'CategoryNameTaken: $name';
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

  /// Every category in the person's order. Equal orders fall back to the name, so the list
  /// never shuffles between reads.
  Stream<List<Category>> watchAll() => (_db.select(
    _db.categories,
  )..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)])).watch();

  /// Renames a category. An empty name, or one another category already has, is refused;
  /// the name is trimmed.
  Future<void> rename(String id, {required String name}) => _db.transaction(() async {
    final trimmed = await _checkedName(id, name);
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(trimmed), updatedAt: Value(clock.now())),
    );
  });

  /// The trimmed name, after refusing an empty one or one another category uses (ignoring
  /// case), so two categories never show the same label.
  Future<String> _checkedName(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    final lower = trimmed.toLowerCase();
    final all = await _db.select(_db.categories).get();
    if (all.any((c) => c.id != id && c.name.trim().toLowerCase() == lower)) {
      throw CategoryNameTaken(trimmed);
    }
    return trimmed;
  }

  /// Saves Edit a category: name, icon and colour, and, when [changeBudget] is true, the
  /// monthly budget ([monthlyBudget] null removes it). All of it is saved or none of it.
  ///
  /// The budget goes through [setBudget], so it behaves exactly as one set on Set a budget:
  /// its carry-over and warn level are kept, and a new budget starts its carry-over clock.
  Future<void> update(
    String id, {
    required String name,
    required String iconKey,
    required String colourToken,
    bool changeBudget = false,
    int? monthlyBudget,
  }) => _db.transaction(() async {
    final current = await _byId(id);
    if (current == null) throw StateError('No category $id');
    if (iconKey.trim().isEmpty) throw ArgumentError.value(iconKey, 'iconKey', 'must be set');
    if (!colourToken.startsWith('cat-')) {
      throw ArgumentError.value(colourToken, 'colourToken', 'must be a cat- colour');
    }
    final trimmed = await _checkedName(id, name);
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(trimmed),
        iconKey: Value(iconKey),
        colourToken: Value(colourToken),
        updatedAt: Value(clock.now()),
      ),
    );
    if (!changeBudget || monthlyBudget == current.monthlyBudget) return;
    if (current.isSystem && monthlyBudget != null) {
      throw ArgumentError('Fees and tax cannot have a budget.');
    }
    if (monthlyBudget != null && monthlyBudget <= 0) {
      throw ArgumentError.value(monthlyBudget, 'monthlyBudget', 'must be above zero');
    }
    await setBudget(
      id,
      monthlyBudget: monthlyBudget,
      // Removing a budget resets its options, as "Remove budget" on Set a budget does.
      carriesOver: monthlyBudget == null ? false : current.budgetCarriesOver,
      warnAt: monthlyBudget == null ? 80 : current.budgetWarnAt,
    );
  });

  Future<Category?> _byId(String id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Where a deleted category's entries go: Other, or Other money in for an income category.
  /// Null when [category] cannot be deleted: Fees and tax, and the two Other categories,
  /// which must always be there to take entries.
  static String? fallbackFor(Category category) {
    if (category.isSystem) return null;
    if (category.id == DefaultIds.other || category.id == DefaultIds.otherIn) return null;
    return category.kind == CategoryKind.income ? DefaultIds.otherIn : DefaultIds.other;
  }

  /// How many entries use the category, so the delete question can say what moves.
  Future<int> entryCount(String id) async {
    final count = _db.transactions.id.count();
    final q = _db.selectOnly(_db.transactions)
      ..addColumns([count])
      ..where(_db.transactions.categoryId.equals(id));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Deletes a category. Its entries and regular payments move to [fallbackFor], and its
  /// budget goes with it. Returns how many entries moved. Fees and tax and the two Other
  /// categories are refused with a [StateError].
  Future<int> delete(String id) => _db.transaction(() async {
    final current = await _byId(id);
    if (current == null) return 0;
    final fallback = fallbackFor(current);
    if (fallback == null) throw StateError('${current.name} cannot be deleted');
    final now = clock.now();
    final moved = await (_db.update(_db.transactions)..where((t) => t.categoryId.equals(id))).write(
      TransactionsCompanion(categoryId: Value(fallback), updatedAt: Value(now)),
    );
    await (_db.update(_db.regularPayments)..where((r) => r.categoryId.equals(id))).write(
      RegularPaymentsCompanion(categoryId: Value(fallback), updatedAt: Value(now)),
    );
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    return moved;
  });

  /// Puts [orderedIds] in this order. Categories not named keep their places, so reordering
  /// the spending list leaves Fees and tax and the money-in list where they were.
  Future<void> reorder(List<String> orderedIds) => _db.transaction(() async {
    final all = await (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)])).get();
    final moving = orderedIds.toSet();
    final known = {for (final c in all) c.id};
    final queue = [
      for (final id in orderedIds)
        if (known.contains(id)) id,
    ];
    if (queue.length != moving.length) {
      throw ArgumentError.value(orderedIds, 'orderedIds', 'must name each category once');
    }
    // Each place a named category held is filled by the next one in the new order.
    var next = 0;
    final order = [for (final c in all) moving.contains(c.id) ? queue[next++] : c.id];
    final now = clock.now();
    final byId = {for (final c in all) c.id: c};
    await _db.batch((b) {
      for (final (i, id) in order.indexed) {
        if (byId[id]!.sortOrder == i) continue;
        b.update(
          _db.categories,
          CategoriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (c) => c.id.equals(id),
        );
      }
    });
  });

  /// Shows or hides a category on Add and in its lists. Entries already made keep it.
  Future<void> setHidden(String id, {required bool hidden}) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(hidden: Value(hidden), updatedAt: Value(clock.now())),
      );

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

  // --- Added for Money-in categories (phase 5). Kept apart from the methods above, which
  // Edit a category owns, so the two can be merged without conflict. ---

  /// Adds a category at the end of the person's order and returns its id. The name follows
  /// the same rule as [rename]: trimmed, and refused when empty ([ArgumentError]) or when
  /// another category has it ([CategoryNameTaken]). A spending category can start with a
  /// [monthlyBudget]; a money-in category cannot. All of it is saved or none of it.
  Future<String> add({
    required String name,
    required CategoryKind kind,
    required String iconKey,
    required String colourToken,
    int? monthlyBudget,
  }) => _db.transaction(() async {
    if (iconKey.trim().isEmpty) throw ArgumentError.value(iconKey, 'iconKey', 'must be set');
    if (!colourToken.startsWith('cat-')) {
      throw ArgumentError.value(colourToken, 'colourToken', 'must be a cat- colour');
    }
    if (monthlyBudget != null && (kind != CategoryKind.spending || monthlyBudget <= 0)) {
      throw ArgumentError.value(
        monthlyBudget,
        'monthlyBudget',
        'must be above zero, for money out',
      );
    }
    final id = _uuid.v4();
    final trimmed = await _checkedName(id, name);
    final now = clock.now();
    // The order is shared by both kinds, so one past the highest is the end of either list.
    final last = _db.categories.sortOrder.max();
    final top = await (_db.selectOnly(_db.categories)..addColumns([last])).getSingle();
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: trimmed,
            iconKey: iconKey,
            colourToken: colourToken,
            kind: kind,
            sortOrder: Value((top.read(last) ?? -1) + 1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (monthlyBudget != null) {
      await setBudget(id, monthlyBudget: monthlyBudget, carriesOver: false, warnAt: 80);
    }
    return id;
  });
}

class AccountRepository {
  AccountRepository(this._db);
  final AppDatabase _db;

  Stream<List<Account>> watchEnabled() =>
      (_db.select(_db.accounts)
            ..where((a) => a.enabled)
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .watch();

  /// Adds an account at the end of the list, with everything New account asks, and returns
  /// its id. All of it is saved or none of it.
  ///
  /// The name is trimmed; an empty one is refused. [colourToken] must be one of
  /// [accountColourTokens] (left out, the kind's own colour). [openingBalance] is what is in
  /// the account now and cannot be below zero; left out, the balance stays unset until the
  /// person says what is in it. [makeDefault] makes it the account Add opens on, taking that
  /// from whichever account had it, so only one ever does.
  Future<String> add({
    required String name,
    required AccountKind kind,
    String? colourToken,
    int? openingBalance,
    bool askFeeEachTime = false,
    bool countInTotals = true,
    bool makeDefault = false,
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    final colour = colourToken ?? colourForKind(kind);
    if (!accountColourTokens.contains(colour)) {
      throw ArgumentError.value(colourToken, 'colourToken', 'must be an account colour');
    }
    if (openingBalance != null && openingBalance < 0) {
      throw ArgumentError.value(openingBalance, 'openingBalance', 'must not be below zero');
    }
    final now = clock.now();
    final id = _uuid.v4();
    // One past the highest, so the new account is last even after others were removed.
    final last = _db.accounts.sortOrder.max();
    final top = await (_db.selectOnly(_db.accounts)..addColumns([last])).getSingle();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            name: trimmed,
            kind: kind,
            colourToken: colour,
            openingBalance: Value(openingBalance ?? 0),
            balanceAt: Value(openingBalance == null ? null : now),
            askFeeEachTime: Value(askFeeEachTime),
            countInTotals: Value(countInTotals),
            sortOrder: Value((top.read(last) ?? -1) + 1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (makeDefault) await _moveDefaultTo(id, now);
    return id;
  });

  /// Says what is in account [id] now: its balance becomes [amount], and from now on each
  /// entry dated from this moment changes it. Entries dated earlier were already in it. An
  /// amount below zero or an unknown id is refused and nothing changes.
  Future<void> setBalanceToday(String id, int amount) => _db.transaction(() async {
    if (amount < 0) throw ArgumentError.value(amount, 'amount', 'must not be below zero');
    final now = clock.now();
    final changed = await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        openingBalance: Value(amount),
        balanceAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (changed == 0) throw StateError('No account $id');
  });

  /// Makes [id] the account Add opens on. Only one account is the default, so the one that
  /// was loses it. An unknown id is refused with a [StateError] and nothing changes.
  Future<void> setDefault(String id) => _db.transaction(() async {
    final row = await (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('No account $id');
    await _moveDefaultTo(id, clock.now());
  });

  Future<void> _moveDefaultTo(String id, DateTime now) async {
    await (_db.update(_db.accounts)..where((a) => a.isDefault & a.id.equals(id).not())).write(
      AccountsCompanion(isDefault: const Value(false), updatedAt: Value(now)),
    );
    await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(isDefault: const Value(true), updatedAt: Value(now)),
    );
  }

  /// The six colours New account offers, in the drawn order: the four account colours, then
  /// purple and teal from the category colours.
  static const accountColourTokens = [
    'acct-mtn',
    'acct-airtel',
    'acct-bank',
    'acct-cash',
    'cat-purple',
    'cat-teal',
  ];

  /// The colour an account of this kind starts with. A mobile money account the person adds
  /// starts yellow, like MTN MoMo; "Other" has no colour of its own yet, so it borrows the
  /// bank colour.
  static String colourForKind(AccountKind kind) => switch (kind) {
    AccountKind.cash => 'acct-cash',
    AccountKind.mtn || AccountKind.mobile => 'acct-mtn',
    AccountKind.airtel => 'acct-airtel',
    AccountKind.bank || AccountKind.other => 'acct-bank',
  };

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
