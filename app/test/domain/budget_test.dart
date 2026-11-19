import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/budget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

BudgetStatus _status({
  required int spent,
  int budget = 200000,
  int warnAt = 80,
  int day = 19,
  int daysInMonth = 30,
}) =>
    budgetStatus(spent: spent, budget: budget, warnAt: warnAt, day: day, daysInMonth: daysInMonth);

void main() {
  group('pace', () {
    test('is the day over the days in the month', () {
      expect(budgetPace(day: 19, daysInMonth: 30), closeTo(19 / 30, 1e-9));
      expect(budgetPace(day: 30, daysInMonth: 30), 1);
    });

    test('is clamped and safe with no days', () {
      expect(budgetPace(day: 40, daysInMonth: 30), 1);
      expect(budgetPace(day: 1, daysInMonth: 0), 0);
    });
  });

  group('the four statuses, at their boundaries', () {
    // Pace on day 19 of 30 is 19/30 (about 63%), and the default warn level is 80%.
    test('exactly the budget is not over, it is nearly used', () {
      expect(_status(spent: 200000), BudgetStatus.nearlyUsed);
    });

    test('one shilling over the budget is over', () {
      expect(_status(spent: 200001), BudgetStatus.over);
    });

    test('exactly at the warn level is nearly used', () {
      // 80% of 200,000 is 160,000.
      expect(_status(spent: 160000), BudgetStatus.nearlyUsed);
    });

    test('one shilling below the warn level is not nearly used', () {
      expect(_status(spent: 159999), BudgetStatus.aLittleAhead);
    });

    test('above pace but under the warn level is a little ahead', () {
      expect(_status(spent: 130000), BudgetStatus.aLittleAhead);
    });

    test('exactly on pace is on track, not ahead', () {
      // 19/30 of 300,000 is exactly 190,000.
      expect(_status(spent: 190000, budget: 300000, warnAt: 90), BudgetStatus.onTrack);
    });

    test('one shilling above pace is a little ahead', () {
      expect(_status(spent: 190001, budget: 300000, warnAt: 90), BudgetStatus.aLittleAhead);
    });

    test('nothing spent on the first day is on track', () {
      expect(_status(spent: 0, day: 1), BudgetStatus.onTrack);
    });

    test('over beats nearly used, and nearly used beats a little ahead', () {
      expect(_status(spent: 300000, warnAt: 50), BudgetStatus.over);
      expect(_status(spent: 170000), BudgetStatus.nearlyUsed);
    });

    test('the drawn Budgets screen: transport over, food nearly used, bills a little ahead', () {
      expect(_status(spent: 236000), BudgetStatus.over, reason: 'Transport, over by 36,000');
      expect(
        _status(spent: 412000, budget: 450000),
        BudgetStatus.nearlyUsed,
        reason: 'Food, 92% used on 63% pace',
      );
      expect(
        _status(spent: 198000, budget: 250000),
        BudgetStatus.aLittleAhead,
        reason: 'Bills, 79% used on 63% pace, under the 80% warn level',
      );
    });

    test('a budget of zero is refused', () {
      expect(() => _status(spent: 0, budget: 0), throwsArgumentError);
    });
  });

  group('the daily allowance', () {
    test('is what is left over the days left, rounded down to the hundred', () {
      // 54,000 over 11 days is 4,909 a day, shown as 4,900 (the drawn figure).
      expect(allowancePerDay(budget: 900000, spent: 846000, daysLeft: 11), 4900);
      // Food: 38,000 over 11 days is 3,454, shown as 3,400.
      expect(allowancePerDay(budget: 450000, spent: 412000, daysLeft: 11), 3400);
    });

    test('is zero once the budget is spent or over', () {
      expect(allowancePerDay(budget: 200000, spent: 236000, daysLeft: 11), 0);
      expect(allowancePerDay(budget: 200000, spent: 200000, daysLeft: 11), 0);
    });

    test('on the last day it is what remains', () {
      expect(allowancePerDay(budget: 200000, spent: 150000, daysLeft: 0), 50000);
    });
  });

  group('the overall figure', () {
    test('is the sum of the budgets, less the sum of what was spent, net', () {
      final t = budgetTotalsOf([
        (budget: 200000, spent: 236000), // Transport, over
        (budget: 450000, spent: 412000), // Food
        (budget: 250000, spent: 198000), // Bills
      ]);
      expect(t.budget, 900000);
      expect(t.spent, 846000);
      expect(t.left, 54000, reason: 'the drawn "Left to spend" figure');
    });

    test('with no budgets it is empty', () {
      expect(budgetTotalsOf(const []).left, 0);
    });
  });

  group('carry-over', () {
    test('the unspent part carries into the next month', () {
      expect(carryIntoNextMonth(budget: 200000, spent: 150000), 50000);
    });

    test('an overspend carries nothing', () {
      expect(carryIntoNextMonth(budget: 200000, spent: 260000), 0);
    });

    test('a month with carry-over on adds it to the base budget', () {
      expect(effectiveBudget(base: 200000, carriesOver: true, previousSpent: 150000), 250000);
    });

    test('applies only once the budget covered the whole of last month', () {
      // November's previous month starts on 1 October (20261001).
      expect(carryApplies(budgetSince: 20260915, previousMonthStartDay: 20261001), isTrue);
      expect(carryApplies(budgetSince: 20261001, previousMonthStartDay: 20261001), isTrue);
      expect(
        carryApplies(budgetSince: 20261002, previousMonthStartDay: 20261001),
        isFalse,
        reason: 'set part-way through October: October was not a full budget month',
      );
      expect(carryApplies(budgetSince: 20261105, previousMonthStartDay: 20261001), isFalse);
      expect(carryApplies(budgetSince: null, previousMonthStartDay: 20261001), isFalse);
    });

    test('with carry-over off the base budget stands', () {
      expect(effectiveBudget(base: 200000, carriesOver: false, previousSpent: 150000), 200000);
    });
  });

  group('the suggested budget', () {
    // The drawn sheet: the last six months, oldest first.
    final drawn = [182000, 205000, 196000, 228000, 244000, 236000];

    test('is the amount that covers five of the six months, rounded up to 10,000', () {
      expect(suggestedBudget(drawn), 240000);
      expect(monthsCovered(drawn, 240000), 5, reason: 'the sheet says "covered 5 of them"');
    });

    test('a budget of 200,000 was over in four of the six months, as the sheet says', () {
      expect(drawn.where((m) => m > 200000).length, 4);
    });

    test('is not offered with fewer than three months of history', () {
      expect(suggestedBudget([100000, 120000]), isNull);
    });

    test('with exactly three months it works from those three', () {
      expect(suggestedBudget([100000, 200000, 150000]), 200000);
    });

    test('only the latest six months count', () {
      expect(suggestedBudget([900000, ...drawn]), 240000);
    });

    test('a month with no spending counts as zero', () {
      expect(suggestedBudget([0, 0, 0, 0, 0, 0]), 0);
    });
  });

  group('previous months', () {
    test('returns the six months before the current one, oldest first', () {
      const calc = PeriodCalculator();
      final months = previousMonths(calc, calc.month(DateTime(2026, 11, 19)));
      expect(months.length, 6);
      expect(months.first.start, DateTime(2026, 5));
      expect(months.last.start, DateTime(2026, 10));
    });
  });

  group('money out per month', () {
    test('totals one category over each month, oldest first', () {
      const calc = PeriodCalculator();
      final months = previousMonths(calc, calc.month(DateTime(2026, 11, 19)));
      final rows = [
        txRow(id: 'a', amount: 50000, day: 20261020),
        txRow(id: 'b', amount: 20000, day: 20261105),
        txRow(id: 'c', amount: 99000, categoryId: DefaultIds.transport, day: 20261020),
        txRow(
          id: 'd',
          direction: Direction.moneyIn,
          amount: 70000,
          categoryId: DefaultIds.salary,
          day: 20261020,
        ),
      ];
      final totals = monthlyMoneyOut(categoryId: DefaultIds.food, months: months, rows: rows);
      expect(totals.length, 6);
      expect(totals.sublist(0, 5), [0, 0, 0, 0, 0], reason: 'May to September');
      expect(totals[5], 50000, reason: 'October, the month before November');
      // The 20 November entry is this month, so it is not in the six.
    });
  });
}
