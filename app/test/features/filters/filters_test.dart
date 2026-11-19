import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/transaction_filter.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/filters/filters_screen.dart';
import 'package:akatabo/features/filters/transaction_filter_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/features/transactions/transactions_providers.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 10);

// Three entries: a food purchase, a bills payment with a fee paid in cash, and a transfer.
final _txs = [
  txRow(id: 'food', amount: 20000, day: 20261119),
  txRow(
    id: 'bills',
    amount: 90000,
    categoryId: DefaultIds.bills,
    accountId: DefaultIds.cash,
    fee: 1000,
    day: 20261105,
  ),
  txRow(
    id: 'move',
    direction: Direction.transfer,
    amount: 50000,
    toAccountId: DefaultIds.cash,
    day: 20261110,
  ),
];

final _cats = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(id: DefaultIds.bills, name: 'Bills'),
];

final _accounts = [
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo'),
  accountRow(id: DefaultIds.cash, name: 'Cash', kind: AccountKind.cash),
  // Switched off in Settings, but its entries are still in the list.
  accountRow(id: 'acct.old', name: 'Old wallet', enabled: false),
];

ProviderContainer _container() => ProviderContainer(
  overrides: [
    appNowProvider.overrideWith((ref) => _now),
    storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
    allTransactionsProvider.overrideWith((ref) => Stream.value(_txs)),
    allCategoriesProvider.overrideWith((ref) => Stream.value(_cats)),
    allAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
  ],
);

void main() {
  Future<void> pumpScreen(WidgetTester tester, ProviderContainer container) async {
    tester.view
      ..physicalSize = const Size(390, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAkTheme(Brightness.light, const AkAppearance()),
          home: const FiltersScreen(),
        ),
      ),
    );
    // The lists arrive from the overridden streams on the next frames.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('with no choice, the button counts every entry', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    expect(find.text('Show 3 transactions'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);
  });

  testWidgets('a category narrows the count and shows Clear all', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.tap(find.text('Food and shopping'));
    await tester.pump();

    expect(find.text('Show 1 transaction'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(container.read(transactionFilterProvider).categoryIds, {DefaultIds.food});
  });

  testWidgets('a second tap on a category clears it again', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.tap(find.text('Bills'));
    await tester.pump();
    await tester.tap(find.text('Bills'));
    await tester.pump();

    expect(find.text('Show 3 transactions'), findsOneWidget);
  });

  testWidgets('an amount from the typed digits keeps entries at or above it', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.pump();

    expect(container.read(transactionFilterProvider).minAmount, 50000);
    expect(find.text('Show 2 transactions'), findsOneWidget);
  });

  testWidgets('a lowest amount above the highest is refused and explained', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.enterText(find.byType(TextField).first, '60000');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '10000');
    await tester.pump();

    expect(find.textContaining('The lowest amount is above the highest.'), findsOneWidget);
    // Neither limit applies while the pair is out of order, so the list is not narrowed by
    // values the fields no longer show as valid.
    final f = container.read(transactionFilterProvider);
    expect(f.minAmount, isNull);
    expect(f.maxAmount, isNull);
    // Show is disabled, so the person cannot leave with the bad pair.
    final show = tester.widget<AkPrimaryButton>(find.byType(AkPrimaryButton));
    expect(show.onPressed, isNull);
  });

  testWidgets('an account switched off still shows its chip', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    expect(find.text('Old wallet'), findsOneWidget);
    await tester.tap(find.text('Old wallet'));
    await tester.pump();
    expect(container.read(transactionFilterProvider).accountIds, {'acct.old'});
  });

  testWidgets('Clear all resets the choices and the order', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await pumpScreen(tester, container);

    await tester.tap(find.text('Cash'));
    await tester.pump();
    await tester.tap(find.text('Largest'));
    await tester.pump();
    expect(container.read(transactionFilterProvider).order, FilterOrder.largest);

    await tester.tap(find.text('Clear all'));
    await tester.pump();

    expect(container.read(transactionFilterProvider).narrows, isFalse);
    expect(container.read(transactionFilterProvider).order, FilterOrder.newest);
    expect(find.text('Show 3 transactions'), findsOneWidget);
  });
}
