import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/seed/default_data.dart';
import '../../data/settings/setting_keys.dart';
import '../../domain/budget.dart';
import '../../domain/spending.dart';
import 'notifications_service.dart';

final budgetWarnerProvider = Provider<BudgetWarner>(BudgetWarner.new);

/// Budget warnings use ids from here up, one per category, clear of the reminder ids.
const budgetWarningIdBase = 1000;

/// How far a budget has gone: 0 before its warn level, 1 nearly used, 2 over.
int _line(BudgetStatus s) => switch (s) {
  BudgetStatus.over => 2,
  BudgetStatus.nearlyUsed => 1,
  BudgetStatus.aLittleAhead || BudgetStatus.onTrack => 0,
};

/// The line an entry has just crossed, or null when it crossed none.
///
/// The statuses come from [budgetStatus], the rule the Budgets screen uses, so the warning
/// and the screen always agree. Nearly used, then Over: each line is warned about once, and
/// an entry that jumps straight past both warns once, as Over.
BudgetStatus? crossedBudgetLine({
  required int spentBefore,
  required int spentAfter,
  required int budget,
  required int warnAt,
  required int day,
  required int daysInMonth,
}) {
  BudgetStatus at(int spent) => budgetStatus(
    spent: spent,
    budget: budget,
    warnAt: warnAt,
    day: day,
    daysInMonth: daysInMonth,
  );
  final before = at(spentBefore);
  final after = at(spentAfter);
  return _line(after) > _line(before) ? after : null;
}

/// After an entry is saved, warns once if it took its category's budget past the budget's
/// own warn level, or over the budget. Only for money out in the current budget month, and
/// only while "Warn me when a budget is nearly used" is on.
class BudgetWarner {
  BudgetWarner(this._ref);
  final Ref _ref;

  /// Checks the saved entry [transactionId]. Never throws: a failure is reported and the
  /// entry stays saved.
  Future<void> afterSave(String transactionId) async {
    try {
      await _check(transactionId);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo budget warning'),
      );
    }
  }

  Future<void> _check(String transactionId) async {
    final settings = await _ref.read(storedSettingsProvider.future);
    if (!SettingKeys.budgetWarn.decode(settings[SettingKeys.budgetWarn.name])) return;

    final transactions = _ref.read(transactionRepositoryProvider);
    final entry = await transactions.byId(transactionId);
    if (entry == null || entry.direction != Direction.moneyOut) return;

    final calc = _ref.read(periodCalculatorProvider);
    final today = dateOnly(clock.now());
    final month = calc.month(today);
    // A budget month that has ended is not warned about.
    if (!month.containsDay(entry.localDay)) return;

    // As the category totals count it: no category means Other.
    final categoryId = entry.categoryId ?? DefaultIds.other;
    final cats = await _ref.read(categoryRepositoryProvider).watchAll().first;
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;
    final base = cat?.monthlyBudget ?? 0;
    if (cat == null || cat.isSystem || cat.hidden || base <= 0) return;

    final rows = await transactions.watchIn(month).first;
    final previous = await transactions.watchIn(calc.previous(month)).first;
    final after = moneyOutByCategory(rows)[cat.id] ?? 0;
    final before = moneyOutByCategory(rows.where((t) => t.id != entry.id))[cat.id] ?? 0;
    final budget = effectiveBudget(
      base: base,
      carriesOver:
          cat.budgetCarriesOver &&
          carryApplies(
            budgetSince: cat.budgetSince,
            previousMonthStartDay: calc.previous(month).startDay,
          ),
      previousSpent: moneyOutByCategory(previous)[cat.id] ?? 0,
    );

    final crossed = crossedBudgetLine(
      spentBefore: before,
      spentAfter: after,
      budget: budget,
      warnAt: cat.budgetWarnAt,
      day: calc.elapsedDays(month, today),
      daysInMonth: month.lengthInDays,
    );
    if (crossed == null) return;

    final (title, body) = budgetWarningText(
      name: cat.name,
      status: crossed,
      spent: after,
      budget: budget,
    );
    await _ref
        .read(notificationsServiceProvider)
        .showNow(budgetWarningIdBase + _stableId(cat.id), title, body);
  }
}

/// The notification's title and body, in the Budgets screen's words.
(String, String) budgetWarningText({
  required String name,
  required BudgetStatus status,
  required int spent,
  required int budget,
}) => switch (status) {
  BudgetStatus.over => (
    'Over budget in $name',
    'Over by ${formatUgx(spent - budget)}. ${formatUgx(spent)} spent of '
        '${formatUgx(budget)} this month.',
  ),
  _ => (
    '$name is nearly used',
    '${formatUgx(spent)} spent of ${formatUgx(budget)} this month, '
        '${formatUgx(budget - spent)} left.',
  ),
};

/// A small number from a category id that is the same on every run, so a category's newer
/// warning replaces its older one.
int _stableId(String id) {
  var h = 0;
  for (final unit in id.codeUnits) {
    h = (h * 31 + unit) % 100000;
  }
  return h;
}
