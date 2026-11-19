import 'dart:async';

import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/transactions/transaction_detail_screen.dart';
import 'package:akatabo/features/transactions/transactions_providers.dart';
import 'package:akatabo/features/transactions/transactions_screen.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(
    id: DefaultIds.transport,
    name: 'Transport',
    iconKey: 'bus',
    colourToken: 'cat-amber',
  ),
  categoryRow(id: DefaultIds.salary, name: 'Salary', iconKey: 'work', kind: CategoryKind.income),
];

final _accounts = [
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true),
  accountRow(id: DefaultIds.cash, name: 'Cash', colourToken: 'acct-cash'),
];

final _rows = [
  txRow(
    id: 'groceries',
    amount: 45000,
    fee: 1000,
    description: 'Groceries, Nakasero market',
    day: 20261119,
    at: _now,
  ),
  txRow(
    id: 'boda',
    amount: 8000,
    categoryId: DefaultIds.transport,
    accountId: DefaultIds.cash,
    description: 'Boda to town',
    day: 20261119,
    at: DateTime(2026, 11, 19, 8, 2),
  ),
  txRow(
    id: 'yaka',
    amount: 30000,
    categoryId: DefaultIds.transport,
    description: 'Yaka electricity',
    day: 20261118,
    at: DateTime(2026, 11, 18, 19, 40),
  ),
  txRow(
    id: 'pay',
    direction: Direction.moneyIn,
    amount: 250000,
    categoryId: DefaultIds.salary,
    description: 'Payment from client',
    day: 20261117,
    at: DateTime(2026, 11, 17, 14, 30),
  ),
];

class _FakeRepo extends TransactionRepository {
  _FakeRepo() : super(AppDatabase(NativeDatabase.memory()));

  final deleted = <String>[];

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

Future<_FakeRepo> _pump(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.light,
  Stream<List<Transaction>>? all,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        transactionRepositoryProvider.overrideWithValue(repo),
        allTransactionsProvider.overrideWith((ref) => all ?? Stream.value(_rows)),
        transactionByIdProvider('groceries').overrideWith((ref) => Stream.value(_rows.first)),
        monthRowsProvider.overrideWith((ref) => Stream.value(_rows)),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_categories)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
      ],
      child: MaterialApp(theme: buildAkTheme(brightness, const AkAppearance()), home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('entries are grouped by day with the day net', (tester) async {
    await _pump(tester, const TransactionsScreen());
    expect(find.text('Today, 19 Nov'), findsOneWidget);
    expect(find.text('Yesterday, 18 Nov'), findsOneWidget);
    expect(find.text('Tuesday, 17 Nov'), findsOneWidget);
    // Today: 45,000 + 1,000 fee + 8,000 out = 54,000.
    expect(find.text('- 54,000'), findsOneWidget);
    expect(find.text('+ 250,000'), findsNWidgets(2), reason: 'the day header and the payment row');
  });

  testWidgets('search matches words and digits', (tester) async {
    await _pump(tester, const TransactionsScreen());
    await tester.enterText(find.byType(TextField), 'boda');
    await tester.pump();
    expect(find.text('Boda to town'), findsOneWidget);
    expect(find.text('Yaka electricity'), findsNothing);

    await tester.enterText(find.byType(TextField), '30000');
    await tester.pump();
    expect(find.text('Yaka electricity'), findsOneWidget);
    expect(find.text('Boda to town'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pump();
    expect(find.text('No entries match. Try another word or amount.'), findsOneWidget);
  });

  testWidgets('the money in filter shows only income', (tester) async {
    await _pump(tester, const TransactionsScreen());
    await tester.tap(find.text('Money in'));
    await tester.pumpAndSettle();
    expect(find.text('Payment from client'), findsOneWidget);
    expect(find.text('Yaka electricity'), findsNothing);
  });

  testWidgets('one entry shows its fee and total cost', (tester) async {
    await _pump(tester, const TransactionDetailScreen(id: 'groceries'));
    expect(find.text('Groceries, Nakasero market'), findsOneWidget);
    expect(find.text('- UGX 45,000'), findsOneWidget);
    expect(find.text('UGX 1,000'), findsOneWidget);
    expect(find.text('UGX 46,000'), findsOneWidget, reason: 'total cost to you');
    expect(find.text('Today, 19 November 2026, 09:14'), findsOneWidget);
  });

  testWidgets('delete asks first and removes only when confirmed', (tester) async {
    final repo = await _pump(tester, const TransactionDetailScreen(id: 'groceries'));
    await tester.tap(find.bySemanticsLabel('Delete this entry'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.bySemanticsLabel('Delete this entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['groceries']);
  });

  for (final b in Brightness.values) {
    testWidgets('transactions goldens, ${b.name}', (tester) async {
      await _pump(tester, const TransactionsScreen(), brightness: b);
      await expectLater(
        find.byType(TransactionsScreen),
        matchesGoldenFile('goldens/transactions_${b.name}.png'),
      );
      await _pump(tester, const TransactionDetailScreen(id: 'groceries'), brightness: b);
      await expectLater(
        find.byType(TransactionDetailScreen),
        matchesGoldenFile('goldens/transaction_detail_${b.name}.png'),
      );
    });
  }

  testWidgets('one day from Calendar shows only that day, with its name', (tester) async {
    await _pump(tester, const TransactionsScreen(day: 20261118));
    expect(find.text('Wednesday 18 November'), findsOneWidget);
    expect(find.text('Yaka electricity'), findsOneWidget);
    expect(find.text('Payment from client'), findsNothing);
    expect(find.byType(AkPillButton), findsNothing, reason: 'no Calendar pill on one day');
    expect(find.text('Calendar'), findsOneWidget, reason: 'the back link returns to Calendar');
  });

  testWidgets('opened from Calendar, back says Calendar and the pill goes back', (tester) async {
    await _pump(tester, const TransactionsScreen(fromCalendar: true));
    expect(find.bySemanticsLabel(RegExp('^Calendar')), findsWidgets);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('while entries load, a day is not called empty', (tester) async {
    await _pump(
      tester,
      const TransactionsScreen(day: 20261118),
      all: StreamController<List<Transaction>>().stream,
    );
    expect(find.text('Nothing added on this day.'), findsNothing);
    expect(find.textContaining('Nothing here yet'), findsNothing);
  });

  testWidgets('a day with nothing on it says so', (tester) async {
    await _pump(tester, const TransactionsScreen(day: 20261101));
    expect(find.text('Nothing added on this day.'), findsOneWidget);
  });
}
