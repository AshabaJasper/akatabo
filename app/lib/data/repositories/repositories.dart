import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/period.dart';
import '../../domain/currency.dart';
import '../../domain/goals.dart';
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
    this.foreignCurrency,
    this.foreignAmountMinor,
    this.rateMicros,
  });

  final Direction direction;

  /// The shillings. For a foreign payment, this is the converted amount.
  final int amount;

  /// The currency paid in when it was not shillings, with its amount in hundredths and the
  /// rate used. All three are null, or all set together.
  final String? foreignCurrency;
  final int? foreignAmountMinor;
  final int? rateMicros;
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
    if (foreignCurrency != null &&
        (foreignAmountMinor == null || rateMicros == null || !isForeignCode(foreignCurrency!)))
      'Enter the foreign amount and its rate.',
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
      foreignCurrency: Value(d.foreignCurrency),
      foreignAmountMinor: Value(d.foreignAmountMinor),
      rateMicros: Value(d.rateMicros),
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

  /// "This was me" on an unusual entry: it is not pointed out again, and the answer is
  /// kept so the share of flags the person waves away can be measured.
  ///
  /// `updatedAt` is left alone: category suggestion reads it as when the category was last
  /// chosen, and answering a flag is not choosing a category. (A restore that merges this
  /// entry may therefore bring the flag back; the person can answer it again.)
  Future<void> dismissUnusual(String id) => (_db.update(
    _db.transactions,
  )..where((t) => t.id.equals(id))).write(const TransactionsCompanion(flagDismissed: Value(true)));

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

  /// Every transaction once, in no particular order (for rebuilding what Smart help learned).
  Future<List<Transaction>> listAll() => _db.select(_db.transactions).get();

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

  /// Changes what Edit account asks: name, kind, colour and the two switches. [makeDefault]
  /// true makes it the account Add opens on; false takes that away if it had it (Add then
  /// opens on the first account switched on); null leaves it. The balance is not here: it is
  /// set on the Accounts page. The same checks as [add] apply, and an unknown id is refused.
  Future<void> update(
    String id, {
    required String name,
    required AccountKind kind,
    required String colourToken,
    required bool askFeeEachTime,
    required bool countInTotals,
    bool? makeDefault,
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    if (!accountColourTokens.contains(colourToken)) {
      throw ArgumentError.value(colourToken, 'colourToken', 'must be an account colour');
    }
    final now = clock.now();
    final changed = await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(trimmed),
        kind: Value(kind),
        colourToken: Value(colourToken),
        askFeeEachTime: Value(askFeeEachTime),
        countInTotals: Value(countInTotals),
        updatedAt: Value(now),
      ),
    );
    if (changed == 0) throw StateError('No account $id');
    if (makeDefault == true) await _moveDefaultTo(id, now);
    if (makeDefault == false) {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(isDefault: const Value(false), updatedAt: Value(now)),
      );
    }
  });

  /// Entries that use account [id]: paid from it or moved to it.
  Future<int> entriesIn(String id) async {
    final count = _db.transactions.id.count();
    final row =
        await (_db.selectOnly(_db.transactions)
              ..addColumns([count])
              ..where(
                _db.transactions.accountId.equals(id) | _db.transactions.toAccountId.equals(id),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Savings-goal moves with money set aside in account [id].
  Future<int> goalMovesIn(String id) async {
    final count = _db.goalMoves.id.count();
    final row =
        await (_db.selectOnly(_db.goalMoves)
              ..addColumns([count])
              ..where(_db.goalMoves.accountId.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Savings goals with any move in account [id], each goal counted once.
  Future<int> goalsIn(String id) async {
    final count = _db.goalMoves.goalId.count(distinct: true);
    final row =
        await (_db.selectOnly(_db.goalMoves)
              ..addColumns([count])
              ..where(_db.goalMoves.accountId.equals(id)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Everything that uses account [id]: its entries and its savings-goal moves. Either kind
  /// blocks deleting the account.
  Future<int> usedBy(String id) async => await entriesIn(id) + await goalMovesIn(id);

  /// Deletes account [id] for good. Refused with a [StateError], and nothing changes, while
  /// any entry or savings-goal move uses it (switch it off instead, so those keep it), or when it is the
  /// only account switched on (or the only one at all), since Add needs one to offer. If it was the account Add opens on, the next account
  /// switched on takes that over.
  Future<void> delete(String id) => _db.transaction(() async {
    final row = await (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('No account $id');
    if (await usedBy(id) > 0) throw StateError('Account $id is used by entries or goal moves');
    final others =
        await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(id).not())
              ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
            .get();
    if (others.isEmpty) throw StateError('Account $id is the only account');
    if (row.enabled && !others.any((a) => a.enabled)) {
      throw StateError('Account $id is the only account switched on');
    }
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
    if (row.isDefault) {
      final next = others.where((a) => a.enabled).firstOrNull;
      if (next != null) await _moveDefaultTo(next.id, clock.now());
    }
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

  /// Every payment, dismissed ones too: Smart help skips a payee already on this list.
  Stream<List<RegularPayment>> watchAll() => _db.select(_db.regularPayments).watch();

  /// Saves a series Smart help noticed in the entries. With [dismissed] it is stored as
  /// removed, so the same payee is not offered again.
  Future<String> addDetected({
    required String label,
    required String payeeKey,
    required int typicalAmount,
    required int amountLow,
    required int amountHigh,
    required int intervalDays,
    required int nextDueOn,
    required int timesSeen,
    String? categoryId,
    bool dismissed = false,
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
            payeeKey: Value(payeeKey),
            typicalAmount: typicalAmount,
            amountLow: amountLow,
            amountHigh: amountHigh,
            intervalDays: intervalDays,
            nextDueOn: nextDueOn,
            timesSeen: Value(timesSeen),
            source: RegularSource.detected,
            dismissed: Value(dismissed),
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

/// Savings goals: what the person is saving toward, and the moves that set money aside for it
/// inside an account (or take it back out). The saved amount is always the sum of the moves,
/// so it cannot drift from them. Every write is one transaction.
class GoalRepository {
  GoalRepository(this._db);
  final AppDatabase _db;

  /// Goals the person has not put away, in the order they were set.
  Stream<List<Goal>> watchActive() =>
      (_db.select(_db.goals)
            ..where((g) => g.archivedAt.isNull())
            ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
          .watch();

  /// Every goal, archived or not, in the order they were set.
  Stream<List<Goal>> watchAll() =>
      (_db.select(_db.goals)..orderBy([(g) => OrderingTerm.asc(g.sortOrder)])).watch();

  /// Every move in every goal, for the set-aside totals.
  Stream<List<GoalMove>> watchAllMoves() => _db.select(_db.goalMoves).watch();

  Stream<Goal?> watchById(String id) =>
      (_db.select(_db.goals)..where((g) => g.id.equals(id))).watchSingleOrNull();

  /// Moves for one goal, newest first.
  Stream<List<GoalMove>> watchMoves(String goalId) =>
      (_db.select(_db.goalMoves)
            ..where((m) => m.goalId.equals(goalId))
            ..orderBy([(m) => OrderingTerm.desc(m.occurredAt)]))
          .watch();

  /// Adds a goal. The name is trimmed and must not be empty; the target must be above zero; a
  /// date, when given, must not be before today.
  Future<String> add({
    required String name,
    required int target,
    required String colourToken,
    int? targetDay,
    String iconKey = 'wallet',
    GoalRemind remindEvery = GoalRemind.off,
  }) => _db.transaction(() async {
    final trimmed = _checkName(name);
    _checkTarget(target);
    final now = clock.now();
    if (targetDay != null && targetDay < toLocalDay(now)) {
      throw ArgumentError.value(targetDay, 'targetDay', 'must not be before today');
    }
    final max = _db.goals.sortOrder.max();
    final row = await (_db.selectOnly(_db.goals)..addColumns([max])).getSingle();
    final id = const Uuid().v4();
    await _db
        .into(_db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            name: trimmed,
            colourToken: colourToken,
            target: target,
            targetDay: Value(targetDay),
            iconKey: Value(iconKey),
            remindEvery: Value(remindEvery),
            sortOrder: Value((row.read(max) ?? -1) + 1),
          ),
        );
    return id;
  });

  /// Changes a goal's name, target, date, colour, icon or reminder. Its moves are untouched. The
  /// reached-date follows the new target: set when the saved amount meets it, cleared when not.
  Future<void> update(
    String id, {
    required String name,
    required int target,
    required String colourToken,
    int? targetDay,
    String iconKey = 'wallet',
    GoalRemind remindEvery = GoalRemind.off,
  }) => _db.transaction(() async {
    final trimmed = _checkName(name);
    _checkTarget(target);
    final goal = await (_db.select(_db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();
    if (goal == null) throw StateError('No goal $id');
    final now = clock.now();
    final saved = await _savedFor(id);
    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        name: Value(trimmed),
        target: Value(target),
        colourToken: Value(colourToken),
        targetDay: Value(targetDay),
        iconKey: Value(iconKey),
        remindEvery: Value(remindEvery),
        reachedAt: Value(saved >= target ? (goal.reachedAt ?? now) : null),
        updatedAt: Value(now),
      ),
    );
  });

  /// Puts a goal away. Its moves stay, so the money stays set aside until it is taken out.
  Future<void> archive(String id) => _setArchived(id, clock.now());

  /// Brings an archived goal back.
  Future<void> unarchive(String id) => _setArchived(id, null);

  Future<void> _setArchived(String id, DateTime? when) async {
    final changed = await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(archivedAt: Value(when), updatedAt: Value(clock.now())),
    );
    if (changed == 0) throw StateError('No goal $id');
  }

  /// Deletes a goal for good. Refused, and nothing changes, while money is set aside for it:
  /// take the money out first, or archive the goal.
  Future<void> delete(String id) => _db.transaction(() async {
    final exists = await (_db.select(_db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();
    if (exists == null) throw StateError('No goal $id');
    if (await _moveCount(id) > 0) throw StateError('Goal $id has moves, so archive it instead');
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  });

  /// Sets money aside for a goal inside an account (an amount above zero), or takes it back out
  /// (below zero). Refused, and nothing changes, when:
  /// - the amount is zero;
  /// - the goal or the account does not exist;
  /// - money is added to an archived goal;
  /// - more is taken out than is saved.
  ///
  /// Setting money aside may exceed what the account has free. That is allowed, because
  /// balances are not always known; the move sheet warns when the balance is known. Returns the
  /// milestones this move crossed, so the screen can say so.
  Future<List<int>> addMove({
    required String goalId,
    required String accountId,
    required int amount,
    String? note,
  }) => _db.transaction(() async {
    if (amount == 0) throw ArgumentError.value(amount, 'amount', 'must not be zero');
    final goal = await (_db.select(_db.goals)..where((g) => g.id.equals(goalId))).getSingleOrNull();
    if (goal == null) throw StateError('No goal $goalId');
    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) throw StateError('No account $accountId');
    if (amount > 0 && goal.archivedAt != null) throw StateError('Goal $goalId is archived');
    // A take-out is checked against the account it leaves too: money saved in one account
    // cannot be taken out of another.
    if (amount < 0 && await _savedIn(goalId, accountId) + amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'more than is saved for this goal in this account',
      );
    }
    final before = await _savedFor(goalId);
    final after = before + amount;
    if (after < 0) {
      throw ArgumentError.value(amount, 'amount', 'more than is saved for this goal');
    }
    final now = clock.now();
    final trimmedNote = note?.trim();
    await _db
        .into(_db.goalMoves)
        .insert(
          GoalMovesCompanion.insert(
            id: const Uuid().v4(),
            createdAt: now,
            updatedAt: now,
            goalId: goalId,
            accountId: accountId,
            amount: amount,
            note: Value(trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote),
            occurredAt: now,
            localDay: toLocalDay(now),
          ),
        );
    await (_db.update(_db.goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(
        reachedAt: Value(after >= goal.target ? (goal.reachedAt ?? now) : null),
        updatedAt: Value(now),
      ),
    );
    return milestonesCrossed(target: goal.target, before: before, after: after);
  });

  /// Money set aside for a goal now: the sum of its moves.
  Future<int> savedFor(String goalId) => _savedFor(goalId);

  Future<int> _savedFor(String goalId) async {
    final sum = _db.goalMoves.amount.sum();
    final row =
        await (_db.selectOnly(_db.goalMoves)
              ..addColumns([sum])
              ..where(_db.goalMoves.goalId.equals(goalId)))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<int> _savedIn(String goalId, String accountId) async {
    final sum = _db.goalMoves.amount.sum();
    final row =
        await (_db.selectOnly(_db.goalMoves)
              ..addColumns([sum])
              ..where(
                _db.goalMoves.goalId.equals(goalId) & _db.goalMoves.accountId.equals(accountId),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<int> _moveCount(String goalId) async {
    final count = _db.goalMoves.id.count();
    final row =
        await (_db.selectOnly(_db.goalMoves)
              ..addColumns([count])
              ..where(_db.goalMoves.goalId.equals(goalId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  String _checkName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    return trimmed;
  }

  void _checkTarget(int target) {
    if (target <= 0) throw ArgumentError.value(target, 'target', 'must be above zero');
  }
}
