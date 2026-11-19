import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/income.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

Category _income(String id, String name, {bool hidden = false}) {
  final c = categoryRow(id: id, name: name, kind: CategoryKind.income);
  return hidden ? c.copyWith(hidden: true) : c;
}

void main() {
  final cats = [
    categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
    categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
    _income(DefaultIds.salary, 'Salary'),
    _income(DefaultIds.business, 'Business and side work'),
    _income(DefaultIds.refunds, 'Refunds and money back'),
  ];

  test('sums money in and counts payments per income category, in the given order', () {
    final rows = [
      txRow(id: 'a', direction: Direction.moneyIn, amount: 1200000, categoryId: DefaultIds.salary),
      txRow(id: 'b', direction: Direction.moneyIn, amount: 150000, categoryId: DefaultIds.business),
      txRow(id: 'c', direction: Direction.moneyIn, amount: 250000, categoryId: DefaultIds.business),
      txRow(id: 'd', amount: 45000, fee: 1000),
      txRow(id: 'e', direction: Direction.transfer, amount: 90000, toAccountId: DefaultIds.cash),
    ];
    final s = incomeByCategory(cats, rows);

    expect(s.lines.map((l) => l.category.id), [
      DefaultIds.salary,
      DefaultIds.business,
      DefaultIds.refunds,
    ]);
    expect(s.lines.map((l) => l.amount), [1200000, 400000, 0]);
    expect(s.lines.map((l) => l.payments), [1, 2, 0]);
    expect(s.total, 1600000);
    expect(s.total, totalsOf(rows).moneyIn, reason: 'the same rule as Home');
  });

  test('a fee on money in does not change the amount that came in', () {
    final s = incomeByCategory(cats, [
      txRow(direction: Direction.moneyIn, amount: 50000, fee: 500, categoryId: DefaultIds.salary),
    ]);
    expect(s.lines.first.amount, 50000);
    expect(s.total, 50000);
  });

  test('a hidden category is listed only when money came in under it', () {
    final withHidden = [...cats, _income(DefaultIds.gifts, 'Gifts and family', hidden: true)];
    expect(
      incomeByCategory(withHidden, const []).lines.map((l) => l.category.id),
      isNot(contains(DefaultIds.gifts)),
    );
    final s = incomeByCategory(withHidden, [
      txRow(direction: Direction.moneyIn, amount: 50000, categoryId: DefaultIds.gifts),
    ]);
    expect(s.lines.last.category.id, DefaultIds.gifts);
    expect(s.lines.last.amount, 50000);
    expect(s.lines.fold<int>(0, (a, l) => a + l.amount), s.total);
  });

  test('with no entries every category shows zero and the total is zero', () {
    final s = incomeByCategory(cats, const []);
    expect(s.lines, hasLength(3));
    expect(s.lines.every((l) => l.amount == 0 && l.payments == 0), isTrue);
    expect(s.total, 0);
  });
}
