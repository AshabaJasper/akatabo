import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Fixed ids for what every install starts with, so a backup from one phone merges with
/// another phone's defaults instead of duplicating them.
abstract final class DefaultIds {
  static const food = 'cat.food';
  static const school = 'cat.school';
  static const transport = 'cat.transport';
  static const bills = 'cat.bills';
  static const family = 'cat.family';
  static const health = 'cat.health';
  static const other = 'cat.other';

  /// The reserved Fees and tax category. Its totals come from the fee and tax fields.
  static const fees = 'cat.fees';

  static const salary = 'cat.salary';
  static const business = 'cat.business';
  static const gifts = 'cat.gifts';
  static const refunds = 'cat.refunds';
  static const otherIn = 'cat.other-in';

  static const cash = 'acct.cash';
  static const mtn = 'acct.mtn';
  static const airtel = 'acct.airtel';
  static const bank = 'acct.bank';
}

typedef _Cat = (String id, String name, String icon, String colour, CategoryKind kind);

/// Names, icons and colours as drawn on Add, Settings > Categories and Money-in categories.
const List<_Cat> _categories = [
  (DefaultIds.food, 'Food and shopping', 'basket', 'cat-green', CategoryKind.spending),
  (DefaultIds.transport, 'Transport', 'bus', 'cat-amber', CategoryKind.spending),
  (DefaultIds.bills, 'Bills', 'bolt', 'cat-purple', CategoryKind.spending),
  (DefaultIds.school, 'School fees', 'book', 'cat-blue', CategoryKind.spending),
  (DefaultIds.family, 'Family', 'people', 'cat-indigo', CategoryKind.spending),
  (DefaultIds.health, 'Health', 'medical', 'cat-teal', CategoryKind.spending),
  (DefaultIds.other, 'Other', 'dots', 'cat-slate', CategoryKind.spending),
  (DefaultIds.fees, 'Fees and tax', 'cash', 'cat-pink', CategoryKind.spending),
  (DefaultIds.salary, 'Salary', 'work', 'cat-blue', CategoryKind.income),
  (DefaultIds.business, 'Business and side work', 'trend', 'cat-green', CategoryKind.income),
  (DefaultIds.gifts, 'Gifts and family', 'gift', 'cat-pink', CategoryKind.income),
  (DefaultIds.refunds, 'Refunds and money back', 'repeat', 'cat-teal', CategoryKind.income),
  (DefaultIds.otherIn, 'Other money in', 'dots', 'cat-slate', CategoryKind.income),
];

typedef _Acct = (String id, String name, AccountKind kind, String colour);

/// The four accounts on Settings > General, in the drawn order.
const List<_Acct> _accounts = [
  (DefaultIds.cash, 'Cash', AccountKind.cash, 'acct-cash'),
  (DefaultIds.mtn, 'MTN MoMo', AccountKind.mtn, 'acct-mtn'),
  (DefaultIds.airtel, 'Airtel Money', AccountKind.airtel, 'acct-airtel'),
  (DefaultIds.bank, 'Bank', AccountKind.bank, 'acct-bank'),
];

/// Inserts the default categories and accounts. Runs once, when the database is created.
Future<void> insertDefaultData(AppDatabase db) async {
  final now = clock.now();
  await db.batch((b) {
    b.insertAll(db.categories, [
      for (final (i, (id, name, icon, colour, kind)) in _categories.indexed)
        CategoriesCompanion.insert(
          id: id,
          name: name,
          iconKey: icon,
          colourToken: colour,
          kind: kind,
          sortOrder: Value(i),
          isSystem: Value(id == DefaultIds.fees),
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    b.insertAll(db.accounts, [
      for (final (i, (id, name, kind, colour)) in _accounts.indexed)
        AccountsCompanion.insert(
          id: id,
          name: name,
          kind: kind,
          colourToken: colour,
          sortOrder: Value(i),
          // "Picked first when you add: MTN MoMo" on Settings > General.
          isDefault: Value(id == DefaultIds.mtn),
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  });
}
