import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/contrast.dart';
import 'package:akatabo/core/theme/token_colour.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/settings/new_account_screen.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

/// The accounts Add offers, as the screen reads them: MTN MoMo is picked first.
final _enabled = [
  accountRow(id: DefaultIds.cash, name: 'Cash', colourToken: 'acct-cash', askFeeEachTime: false),
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true),
];

/// Refuses every new account, as a locked database would.
class _FailingAccounts extends AccountRepository {
  _FailingAccounts(super.db);

  @override
  Future<String> add({
    required String name,
    required AccountKind kind,
    String? colourToken,
    int? openingBalance,
    bool askFeeEachTime = false,
    bool countInTotals = true,
    bool makeDefault = false,
  }) => Future.error(StateError('database is locked'));
}

List<Override> _overrides(AppDatabase db, {AccountRepository? accounts, List<Account>? all}) => [
  appDatabaseProvider.overrideWithValue(db),
  // Edit account reads every account; a live drift stream would not settle here.
  if (all != null) allAccountsProvider.overrideWith((ref) => Stream.value(all)),
  storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
  enabledAccountsProvider.overrideWith((ref) => Stream.value(_enabled)),
  if (accounts != null) accountRepositoryProvider.overrideWithValue(accounts),
];

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  Brightness brightness = Brightness.light,
  double width = 390,
  double height = 1200,
  AccountRepository? accounts,
  Widget screen = const NewAccountScreen(),
  List<Account>? all,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(db, accounts: accounts, all: all),
      child: MaterialApp(theme: buildAkTheme(brightness, const AkAppearance()), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets a database write finish on the real clock, then redraws the frames it caused.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

Future<List<Account>> _accounts(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.accounts).get()))!;

void main() {
  group('the account repository', () {
    late AppDatabase db;
    late AccountRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = AccountRepository(db);
    });
    tearDown(() => db.close());

    test('every field on New account is saved', () async {
      final id = await repo.add(
        name: '  Savings for Mum ',
        kind: AccountKind.mobile,
        colourToken: 'cat-purple',
        openingBalance: 120000,
        askFeeEachTime: true,
        countInTotals: false,
      );
      final a = await (db.select(db.accounts)..where((r) => r.id.equals(id))).getSingle();
      expect(a.name, 'Savings for Mum');
      expect(a.kind, AccountKind.mobile);
      expect(a.colourToken, 'cat-purple');
      expect(a.openingBalance, 120000);
      expect(a.balanceAt, isNotNull, reason: 'what is in it today was given');
      expect(a.askFeeEachTime, isTrue);
      expect(a.countInTotals, isFalse);
      expect(a.isDefault, isFalse);
      expect(a.sortOrder, 4, reason: 'after the four default accounts');
    });

    test('the default accounts start with no balance set', () async {
      final all = await db.select(db.accounts).get();
      expect(all.map((a) => a.balanceAt), everyElement(isNull));
    });

    test('saying what is in an account sets its balance from that moment', () async {
      await withClock(Clock.fixed(DateTime(2026, 11, 20, 10)), () async {
        await repo.setBalanceToday(DefaultIds.mtn, 100000);
      });
      final a = await (db.select(
        db.accounts,
      )..where((r) => r.id.equals(DefaultIds.mtn))).getSingle();
      expect(a.openingBalance, 100000);
      expect(a.balanceAt, DateTime(2026, 11, 20, 10));
      await expectLater(repo.setBalanceToday(DefaultIds.mtn, -1), throwsArgumentError);
      await expectLater(repo.setBalanceToday('no-such-account', 5), throwsStateError);
    });

    test('left out, the colour follows the kind', () async {
      final id = await repo.add(name: 'Wallet', kind: AccountKind.cash);
      final a = await (db.select(db.accounts)..where((r) => r.id.equals(id))).getSingle();
      expect(a.colourToken, 'acct-cash');
    });

    test('a colour outside the six, or a balance below zero, is refused', () async {
      await expectLater(
        repo.add(name: 'A', kind: AccountKind.bank, colourToken: 'cat-pink'),
        throwsArgumentError,
      );
      await expectLater(
        repo.add(name: 'A', kind: AccountKind.bank, openingBalance: -1),
        throwsArgumentError,
      );
      expect((await db.select(db.accounts).get()).length, 4, reason: 'nothing was added');
    });

    test('"Pick this first" moves the default, so only one account has it', () async {
      final id = await repo.add(name: 'Stanbic', kind: AccountKind.bank, makeDefault: true);
      var defaults = (await db.select(db.accounts).get()).where((a) => a.isDefault);
      expect(defaults.map((a) => a.id), [id]);

      await repo.setDefault(DefaultIds.cash);
      defaults = (await db.select(db.accounts).get()).where((a) => a.isDefault);
      expect(defaults.map((a) => a.id), [DefaultIds.cash]);

      await expectLater(repo.setDefault('no-such-account'), throwsStateError);
      defaults = (await db.select(db.accounts).get()).where((a) => a.isDefault);
      expect(defaults.map((a) => a.id), [DefaultIds.cash], reason: 'nothing changed');
    });

    test('Add opens on the default account, or the first when it is switched off', () async {
      final enabled = await repo.watchEnabled().first;
      expect(firstPickAccount(enabled)?.id, DefaultIds.mtn);
      await repo.setDefault(DefaultIds.bank);
      expect(firstPickAccount(await repo.watchEnabled().first)?.id, DefaultIds.bank);
      await repo.setEnabled(DefaultIds.bank, enabled: false);
      expect(firstPickAccount(await repo.watchEnabled().first)?.id, DefaultIds.cash);
      expect(firstPickAccount(const []), isNull);
    });

    test('the default accounts ask for the fee, except cash', () async {
      final all = {for (final a in await db.select(db.accounts).get()) a.id: a.askFeeEachTime};
      expect(all, {
        DefaultIds.cash: false,
        DefaultIds.mtn: true,
        DefaultIds.airtel: true,
        DefaultIds.bank: true,
      });
    });
  });

  group('editing and deleting an account', () {
    late AppDatabase db;
    late AccountRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = AccountRepository(db);
    });
    tearDown(() => db.close());

    Future<Account> one(String id) =>
        (db.select(db.accounts)..where((r) => r.id.equals(id))).getSingle();

    test('an edit changes the fields and keeps the id', () async {
      await repo.update(
        DefaultIds.cash,
        name: ' Pocket ',
        kind: AccountKind.other,
        colourToken: 'cat-teal',
        askFeeEachTime: true,
        countInTotals: false,
        makeDefault: true,
      );
      final a = await one(DefaultIds.cash);
      expect(a.name, 'Pocket');
      expect(a.kind, AccountKind.other);
      expect(a.colourToken, 'cat-teal');
      expect(a.askFeeEachTime, isTrue);
      expect(a.countInTotals, isFalse);
      expect(a.isDefault, isTrue);
      expect((await one(DefaultIds.mtn)).isDefault, isFalse, reason: 'only one default');
    });

    test('an empty name or a colour that is not an account colour is refused', () async {
      Future<void> edit(String name, String colour) => repo.update(
        DefaultIds.cash,
        name: name,
        kind: AccountKind.cash,
        colourToken: colour,
        askFeeEachTime: false,
        countInTotals: true,
      );
      await expectLater(edit('  ', 'acct-cash'), throwsArgumentError);
      await expectLater(edit('Cash', 'cat-green'), throwsArgumentError);
      expect((await one(DefaultIds.cash)).name, 'Cash');
    });

    test('an account with entries, paid from or moved to, is not deleted', () async {
      await db.into(db.transactions).insert(txRow(id: 'paid', accountId: DefaultIds.airtel));
      await db
          .into(db.transactions)
          .insert(
            txRow(
              id: 'moved',
              direction: Direction.transfer,
              categoryId: null,
              toAccountId: DefaultIds.bank,
            ),
          );
      expect(await repo.usedBy(DefaultIds.airtel), 1);
      expect(await repo.usedBy(DefaultIds.bank), 1);
      expect(await repo.usedBy(DefaultIds.cash), 0);
      await expectLater(repo.delete(DefaultIds.bank), throwsStateError);
      expect(await db.select(db.accounts).get(), hasLength(4));
    });

    test('deleting the account Add opens on hands that to the next one switched on', () async {
      await repo.setEnabled(DefaultIds.cash, enabled: false);
      await repo.delete(DefaultIds.mtn);
      final left = await db.select(db.accounts).get();
      expect(left.map((a) => a.id), isNot(contains(DefaultIds.mtn)));
      expect(left.where((a) => a.isDefault).map((a) => a.id), [DefaultIds.airtel]);
    });

    test('the only account left is not deleted', () async {
      await repo.delete(DefaultIds.cash);
      await repo.delete(DefaultIds.airtel);
      await repo.delete(DefaultIds.bank);
      await expectLater(repo.delete(DefaultIds.mtn), throwsStateError);
      expect(await db.select(db.accounts).get(), hasLength(1));
    });

    test('the only account switched on is not deleted, even with others switched off', () async {
      for (final id in [DefaultIds.mtn, DefaultIds.airtel, DefaultIds.bank]) {
        await repo.setEnabled(id, enabled: false);
      }
      await expectLater(repo.delete(DefaultIds.cash), throwsStateError);
      expect(await db.select(db.accounts).get(), hasLength(4));
      // A switched-off one can still go.
      await repo.delete(DefaultIds.bank);
      expect(await db.select(db.accounts).get(), hasLength(3));
    });

    testWidgets('Edit account is filled from the account and saves the change', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        screen: const NewAccountScreen(editId: DefaultIds.mtn),
        all: await _accounts(tester, db),
      );
      await _settle(tester);

      expect(find.text('Edit account'), findsOneWidget);
      expect(find.text('MTN MoMo'), findsOneWidget);
      expect(find.text('WHAT IS IN IT TODAY, UGX (OPTIONAL)'), findsNothing);
      expect(find.text('Now it is MTN MoMo'), findsNothing, reason: 'it is this account');
      await tester.enterText(_field('Name'), 'MoMo');
      await tester.tap(find.text('Save changes'));
      await _settle(tester);

      final a = (await _accounts(tester, db)).singleWhere((r) => r.id == DefaultIds.mtn);
      expect(a.name, 'MoMo');
      expect(a.kind, AccountKind.mtn, reason: 'shown as Mobile, kept as its own kind');
      expect(a.isDefault, isTrue);
    });

    testWidgets('Delete on an account with entries offers to switch it off instead', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(
        () => db.into(db.transactions).insert(txRow(id: 'paid', accountId: DefaultIds.airtel)),
      );
      await _pump(
        tester,
        db,
        screen: const NewAccountScreen(editId: DefaultIds.airtel),
        all: await _accounts(tester, db),
      );
      await _settle(tester);

      await tester.tap(find.text('Delete this account'));
      await _settle(tester);
      expect(find.text('Airtel Money is used by 1 entry'), findsOneWidget);
      await tester.tap(find.text('Switch it off'));
      await _settle(tester);

      final a = (await _accounts(tester, db)).singleWhere((r) => r.id == DefaultIds.airtel);
      expect(a.enabled, isFalse);
    });

    testWidgets('Delete names each savings goal once, however many moves it has here', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        final goals = GoalRepository(db);
        final id = await goals.add(name: 'Phone', target: 100000, colourToken: 'cat-teal');
        await goals.addMove(goalId: id, accountId: DefaultIds.airtel, amount: 20000);
        await goals.addMove(goalId: id, accountId: DefaultIds.airtel, amount: -20000);
      });
      await _pump(
        tester,
        db,
        screen: const NewAccountScreen(editId: DefaultIds.airtel),
        all: await _accounts(tester, db),
      );
      await _settle(tester);

      await tester.tap(find.text('Delete this account'));
      await _settle(tester);
      expect(find.text('Airtel Money is used by 1 savings goal'), findsOneWidget);
      expect(find.textContaining('savings-goal history'), findsOneWidget);
    });

    testWidgets('Delete names entries and savings goals together', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        await db.into(db.transactions).insert(txRow(id: 'paid', accountId: DefaultIds.airtel));
        final goals = GoalRepository(db);
        final id = await goals.add(name: 'Phone', target: 100000, colourToken: 'cat-teal');
        await goals.addMove(goalId: id, accountId: DefaultIds.airtel, amount: 20000);
      });
      await _pump(
        tester,
        db,
        screen: const NewAccountScreen(editId: DefaultIds.airtel),
        all: await _accounts(tester, db),
      );
      await _settle(tester);

      await tester.tap(find.text('Delete this account'));
      await _settle(tester);
      expect(find.text('Airtel Money is used by 1 entry and 1 savings goal'), findsOneWidget);
    });

    testWidgets('Delete on an unused account asks first, then deletes it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        screen: const NewAccountScreen(editId: DefaultIds.bank),
        all: await _accounts(tester, db),
      );
      await _settle(tester);

      await tester.tap(find.text('Delete this account'));
      await _settle(tester);
      expect(find.text('No entries use it. Deleting it cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(await _accounts(tester, db), hasLength(4), reason: 'Cancel keeps it');

      await tester.tap(find.text('Delete this account'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      expect((await _accounts(tester, db)).map((a) => a.id), isNot(contains(DefaultIds.bank)));
    });
  });

  group('New account', () {
    testWidgets('shows every field as drawn, with the account Add opens on now', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);

      for (final text in [
        'New account',
        'An account is anywhere you keep money. Akatabo never connects to it; you just pick '
            'it when you add.',
        'NAME',
        'KIND',
        'Cash',
        'Mobile',
        'Bank',
        'Other',
        'COLOUR',
        'WHAT IS IN IT TODAY, UGX (OPTIONAL)',
        'Leave empty to skip',
        'Ask for the fee each time',
        'Shows the fee box when you pay from here',
        'Pick this first when I add',
        'Now it is MTN MoMo',
        'Count it in my totals',
        'Switch off for money you hold for someone else',
        'Save account',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('saves what was entered in each field', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);

      await tester.enterText(_field('Name'), 'Savings for Mum');
      await tester.tap(find.text('Mobile'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Purple'));
      await tester.pump();
      await tester.enterText(_field('What is in it today, UGX (optional)'), '120000');
      await tester.tap(find.bySemanticsLabel('Ask for the fee each time'));
      await tester.tap(find.bySemanticsLabel('Pick this first when I add'));
      await tester.tap(find.bySemanticsLabel('Count it in my totals'));
      await tester.pump();
      await tester.tap(find.text('Save account'));
      await _settle(tester);

      final all = await _accounts(tester, db);
      final a = all.singleWhere((r) => r.name == 'Savings for Mum');
      expect(a.kind, AccountKind.mobile);
      expect(a.colourToken, 'cat-purple');
      expect(a.openingBalance, 120000);
      expect(a.askFeeEachTime, isFalse);
      expect(a.countInTotals, isFalse);
      expect(a.isDefault, isTrue);
      expect(all.where((r) => r.isDefault), hasLength(1), reason: 'MTN MoMo lost it');
    });

    testWidgets('untouched, the switches save as drawn and the colour follows the kind', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);

      await tester.enterText(_field('Name'), 'Pocket');
      await tester.tap(find.text('Cash'));
      await tester.pump();
      await tester.tap(find.text('Save account'));
      await _settle(tester);

      final a = (await _accounts(tester, db)).singleWhere((r) => r.name == 'Pocket');
      expect(a.kind, AccountKind.cash);
      expect(a.colourToken, 'acct-cash');
      expect(a.openingBalance, 0, reason: 'left empty');
      expect(a.balanceAt, isNull, reason: 'left empty, the balance is not set');
      expect(a.askFeeEachTime, isTrue);
      expect(a.countInTotals, isTrue);
      expect(a.isDefault, isFalse);
    });

    testWidgets('an empty name is asked for once, under Name, and typing clears it', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);

      await tester.tap(find.text('Save account'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Give the account a name.'), findsOneWidget);

      await tester.enterText(_field('Name'), 'A');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Give the account a name.'), findsNothing);
    });

    testWidgets('a failed save is said once, below the button, not under Name', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, accounts: _FailingAccounts(db));

      await tester.enterText(_field('Name'), 'Stanbic');
      await tester.tap(find.text('Save account'));
      await _settle(tester);

      const message = 'The account could not be saved. Try again.';
      expect(find.text(message), findsOneWidget);
      final field = tester.widget<TextField>(_field('Name'));
      expect(field.decoration?.errorText, isNull, reason: 'the name is not the problem');
      expect(
        tester.getTopLeft(find.text(message)).dy,
        greaterThan(tester.getTopLeft(find.text('Save account')).dy),
      );
      final button = tester.widget<AkPrimaryButton>(find.byType(AkPrimaryButton));
      expect(button.onPressed, isNotNull, reason: 'the person can try again');
    });

    testWidgets('Done pressed twice saves one account', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);

      await tester.enterText(_field('Name'), 'Airtel wallet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      final all = await _accounts(tester, db);
      expect(all.where((a) => a.name == 'Airtel wallet'), hasLength(1));
    });

    testWidgets('opened as the first route, saving goes to the Accounts page', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/settings/accounts/new',
        routes: [
          GoRoute(
            path: '/settings/accounts',
            builder: (_, _) => const Scaffold(body: Text('Accounts page')),
          ),
          GoRoute(path: '/settings/accounts/new', builder: (_, _) => const NewAccountScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: _overrides(db),
          child: MaterialApp.router(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(_field('Name'), 'Stanbic');
      await tester.tap(find.text('Save account'));
      await _settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('Accounts page'), findsOneWidget);
      expect(find.byType(NewAccountScreen), findsNothing);
    });

    testWidgets('at 360dp each kind fits on one line', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, width: 360);
      for (final (_, label) in newAccountKinds) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        final fontSize = paragraph.text.style?.fontSize ?? 14;
        expect(paragraph.size.height, lessThan(fontSize * 2), reason: '$label must not wrap');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('each colour is a named 44px button, and the chosen one is marked', (tester) async {
      final handle = tester.ensureSemantics();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db);
      for (final name in ['Yellow', 'Red', 'Blue', 'Olive', 'Purple', 'Teal']) {
        final disc = find.bySemanticsLabel(name);
        expect(disc, findsOneWidget, reason: name);
        expect(tester.getSize(disc), const Size.square(AkSize.target));
      }
      // Kind starts as Other, which takes the bank blue until a colour is picked.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Blue')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Yellow')), isSemantics(isSelected: false));
      handle.dispose();
    });
  });

  group('account colours stand out', () {
    for (final (name, c) in [('light', akLightTokens), ('dark', akDarkTokens)]) {
      test('every disc is at least 3:1 against the ground, by fill or edge, in $name', () {
        for (final token in AccountRepository.accountColourTokens) {
          final fill = contrastRatio(colourForToken(c, token), c.ground);
          if (AccountColourChoices.needsEdge(colourForToken(c, token), c.ground)) {
            expect(contrastRatio(c.inkMuted, c.ground), greaterThanOrEqualTo(3), reason: token);
          } else {
            expect(fill, greaterThanOrEqualTo(3), reason: token);
          }
        }
      });
    }
  });

  for (final b in Brightness.values) {
    testWidgets('new account golden, ${b.name}', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, brightness: b, height: 1100);
      await tester.enterText(_field('Name'), 'Centenary savings');
      await tester.tap(find.text('Bank'));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(NewAccountScreen),
        matchesGoldenFile('goldens/new_account_${b.name}.png'),
      );
    });
  }
}
