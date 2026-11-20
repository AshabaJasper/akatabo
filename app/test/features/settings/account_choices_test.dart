import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/settings/accounts_settings_screen.dart';
import 'package:akatabo/features/settings/general_settings_screen.dart';
import 'package:akatabo/features/transactions/transactions_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _mtn = accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true);
final _cash = accountRow(
  id: DefaultIds.cash,
  name: 'Cash',
  colourToken: 'acct-cash',
  kind: AccountKind.cash,
  openingBalance: 20000,
);
final _held = accountRow(
  id: 'held',
  name: 'Savings for Mum',
  colourToken: 'cat-purple',
  openingBalance: 500000,
  countInTotals: false,
);

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  Widget screen, {
  List<Account>? enabled,
  List<Account>? all,
  List<Transaction> rows = const [],
}) async {
  tester.view
    ..physicalSize = const Size(390, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(enabled ?? [_cash, _mtn])),
        allAccountsProvider.overrideWith((ref) => Stream.value(all ?? [_cash, _mtn])),
        allTransactionsProvider.overrideWith((ref) => Stream.value(rows)),
      ],
      child: MaterialApp(theme: buildAkTheme(Brightness.light, const AkAppearance()), home: screen),
    ),
  );
  // Two frames: the page reads the settings first, and only then starts watching the
  // accounts, whose first value arrives a frame later.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Picked first when you add, on General', () {
    testWidgets('names the account Add opens on, and choosing another moves it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, const GeneralSettingsScreen());

      expect(find.text('Picked first when you add'), findsOneWidget);
      expect(find.text('MTN MoMo'), findsOneWidget);

      await tester.tap(find.text('Picked first when you add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      final defaults = await tester.runAsync(
        () async => (await db.select(db.accounts).get()).where((a) => a.isDefault).toList(),
      );
      expect(defaults!.map((a) => a.id), [DefaultIds.cash]);
    });

    testWidgets('with the default switched off, it names the first account, as Add does', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        const GeneralSettingsScreen(),
        enabled: [
          _cash,
          accountRow(id: DefaultIds.bank, name: 'Bank'),
        ],
      );
      expect(find.text('Cash'), findsOneWidget);

      // Choosing that fallback marks it, so Add stays on Cash when MTN MoMo comes back.
      await tester.tap(find.text('Picked first when you add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      final defaults = await tester.runAsync(
        () async => (await db.select(db.accounts).get()).where((a) => a.isDefault).toList(),
      );
      expect(defaults!.map((a) => a.id), [DefaultIds.cash]);
    });
  });

  group('What is in them today, on Accounts', () {
    testWidgets('an account not counted keeps its line but leaves the total', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        const AccountsSettingsScreen(),
        all: [_cash, _mtn, _held],
        rows: [txRow(amount: 5000, accountId: DefaultIds.cash)],
      );

      expect(find.text('WHAT IS IN THEM TODAY'), findsOneWidget);
      // Cash is 20,000 less 5,000; the total is Cash plus MTN's 0, without the 500,000 held.
      expect(find.text('UGX 15,000'), findsNWidgets(2), reason: 'the Cash line and the total');
      expect(find.text('UGX 500,000'), findsOneWidget, reason: 'Savings for Mum keeps its line');
      expect(find.text('UGX 515,000'), findsNothing);
      expect(find.textContaining('Not counted in the total: Savings for Mum.'), findsOneWidget);
    });

    testWidgets('counted, the same account is in the total', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        const AccountsSettingsScreen(),
        all: [_cash, _mtn, _held.copyWith(countInTotals: true)],
      );
      expect(find.text('UGX 520,000'), findsOneWidget, reason: '20,000 + 0 + 500,000');
      expect(find.textContaining('Not counted'), findsNothing);
    });

    testWidgets('an account never set says so and stays out of the total', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        const AccountsSettingsScreen(),
        all: [
          _cash,
          _mtn.copyWith(balanceAt: const Value(null)),
        ],
        rows: [txRow(amount: 45000)], // money out from MTN, whose balance is not set
      );
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('UGX 20,000'), findsNWidgets(2), reason: 'Cash, and the total of Cash');
      expect(find.textContaining('UGX -'), findsNothing, reason: 'no made-up negative balance');
      expect(find.textContaining('Accounts not set are not in the total.'), findsOneWidget);
    });

    testWidgets('tapping an account saves what is in it now', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        const AccountsSettingsScreen(),
        all: [
          _cash,
          _mtn.copyWith(balanceAt: const Value(null)),
        ],
      );

      await tester.tap(find.text('Not set'));
      await tester.pumpAndSettle();
      expect(find.text('What is in MTN MoMo now'), findsOneWidget);

      // Empty is asked for again, not saved as 0.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Type what is in it, or 0 if it is empty.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '100000');
      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      final mtn = await tester.runAsync(
        () => (db.select(db.accounts)..where((a) => a.id.equals(DefaultIds.mtn))).getSingle(),
      );
      expect(mtn!.openingBalance, 100000);
      expect(mtn.balanceAt, isNotNull);
    });
  });
}
