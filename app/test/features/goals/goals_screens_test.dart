import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/goals/goal_detail_screen.dart';
import 'package:akatabo/features/goals/goal_edit_screen.dart';
import 'package:akatabo/features/goals/goals_entry.dart';
import 'package:akatabo/features/goals/goals_screen.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:akatabo/widgets/ak_surfaces.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

final _today = DateTime(2026, 11, 24, 10);

/// A goal store whose writes fail the way a full disk would, not with a refusal.
class _FailingGoals extends GoalRepository {
  _FailingGoals(super.db);

  @override
  Future<List<int>> addMove({
    required String goalId,
    required String accountId,
    required int amount,
    String? note,
  }) async => throw Exception('disk');
}

/// Pumps [screen] on a bare MaterialApp, or the screens [router] reaches when it is given.
/// [stored] is the saved settings, such as "Hide amounts".
Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  Widget? screen, {
  GoRouter? router,
  Map<String, String> stored = const {},
  double height = 1200,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = Size(390, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final accounts = (await tester.runAsync(() => db.select(db.accounts).get()))!;
  final theme = buildAkTheme(Brightness.light, const AkAppearance());
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appNowProvider.overrideWithValue(_today),
        storedSettingsProvider.overrideWith((ref) => Stream.value(stored)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        allAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
        ...overrides,
      ],
      child: router == null
          ? MaterialApp(theme: theme, home: screen)
          : MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// A goal set up on [_today]'s clock (or [on]), with optional [moves] from MTN MoMo.
Future<String> _goal(
  WidgetTester tester,
  GoalRepository goals, {
  String name = 'School fees',
  int target = 100000,
  int? targetDay = 20990101,
  List<int> moves = const [],
  DateTime? on,
}) async {
  late String id;
  await tester.runAsync(() async {
    id = await withClock(
      Clock.fixed(on ?? _today),
      () => goals.add(name: name, target: target, colourToken: 'cat-teal', targetDay: targetDay),
    );
    for (final amount in moves) {
      await withClock(
        Clock.fixed(_today),
        () => goals.addMove(goalId: id, accountId: 'acct.mtn', amount: amount),
      );
    }
  });
  return id;
}

/// Unmounts the screen and lets the timers drift schedules as its streams close fire, so the
/// test ends with none pending.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets a database write finish on the real clock, then redraws the frames it caused.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // The app's MaterialApp loads date symbols through its localisation delegates; this test
  // builds a bare MaterialApp, so load them here or the goal dates cannot be formatted.
  setUpAll(initializeDateFormatting);

  late AppDatabase db;
  late GoalRepository goals;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    goals = GoalRepository(db);
  });
  tearDown(() => db.close());

  testWidgets('the list shows each goal, the total set aside and the reached section', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final school = await withClock(
        Clock.fixed(_today),
        () => goals.add(
          name: 'School fees',
          target: 100000,
          colourToken: 'cat-teal',
          targetDay: 20990101,
        ),
      );
      await withClock(
        Clock.fixed(_today),
        () => goals.addMove(goalId: school, accountId: 'acct.mtn', amount: 40000),
      );
      await withClock(
        Clock.fixed(_today),
        () => goals.add(name: 'Phone', target: 20000, colourToken: 'cat-indigo'),
      );
    });
    await _pump(tester, db, const GoalsScreen());
    await _settle(tester);

    expect(find.text('Savings goals'), findsOneWidget);
    expect(find.text('School fees'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Saving now'), findsOneWidget);
    expect(find.text('Set aside in your accounts'), findsOneWidget);
    expect(find.text('UGX 40,000'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('the list says so when there are no goals yet', (tester) async {
    await _pump(tester, db, const GoalsScreen());
    await _settle(tester);
    expect(find.textContaining('Set money aside for something you want'), findsOneWidget);
    expect(find.text('New goal'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('the detail shows the saved figure, and Set aside adds to it', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await withClock(
        Clock.fixed(_today),
        () => goals.add(
          name: 'School fees',
          target: 100000,
          colourToken: 'cat-teal',
          targetDay: 20990101,
        ),
      );
    });
    await _pump(tester, db, GoalDetailScreen(goalId: id), height: 2400);
    await _settle(tester);

    expect(find.text('School fees'), findsOneWidget);
    expect(find.text('UGX 0'), findsOneWidget);

    await tester.tap(find.text('Add to goal'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '20000');
    await tester.pump();
    tester.widget<AkPrimaryButton>(find.widgetWithText(AkPrimaryButton, 'Set aside')).onPressed!();
    await _settle(tester);

    expect(find.text('UGX 20,000'), findsOneWidget);
    expect(await tester.runAsync(() => goals.savedFor(id)), 20000);
    await _leave(tester);
  });

  testWidgets('the edit form refuses an empty name, then saves a new goal', (tester) async {
    await _pump(tester, db, const GoalEditScreen());
    await _settle(tester);

    await tester.tap(find.text('Save goal'));
    await _settle(tester);
    expect(find.text('Give the goal a name.'), findsOneWidget);
    expect(await tester.runAsync(() => goals.watchActive().first), isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'Phone');
    await tester.enterText(find.byType(TextField).at(1), '800000');
    await tester.pump();
    await tester.tap(find.text('Save goal'));
    await _settle(tester);

    final saved = await tester.runAsync(() => goals.watchActive().first);
    expect(saved!.map((g) => (g.name, g.target)), [('Phone', 800000)]);
    await _leave(tester);
  });

  testWidgets('the Goals tab savings section shows the total, the goals and See all', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final school = await withClock(
        Clock.fixed(_today),
        () => goals.add(name: 'School fees', target: 100000, colourToken: 'cat-teal'),
      );
      await withClock(
        Clock.fixed(_today),
        () => goals.addMove(goalId: school, accountId: 'acct.mtn', amount: 30000),
      );
    });
    await _pump(tester, db, const Scaffold(body: SavingsSection()));
    await _settle(tester);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('School fees'), findsOneWidget);
    expect(find.text('UGX 30,000'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('the Goals tab savings section offers New goal when there are none', (tester) async {
    await _pump(tester, db, const Scaffold(body: SavingsSection()));
    await _settle(tester);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('New goal'), findsOneWidget);
    expect(find.textContaining('No savings goals yet'), findsOneWidget);
    await _leave(tester);
  });

  // Review fixes. Each test names the bug it guards.

  testWidgets('#5 with every goal archived, the section keeps the total and See all', (
    tester,
  ) async {
    final id = await _goal(tester, goals, moves: [30000]);
    await tester.runAsync(() => goals.archive(id));
    await _pump(tester, db, const Scaffold(body: SavingsSection()));
    await _settle(tester);

    expect(find.text('See all'), findsOneWidget);
    expect(find.text('UGX 30,000'), findsOneWidget);
    expect(find.textContaining('All your goals are archived'), findsOneWidget);
    expect(find.textContaining('No savings goals yet'), findsNothing);
    await _leave(tester);
  });

  testWidgets('#1 #4 #11 Edit opens the form, Archive returns to the goal, Unarchive restores', (
    tester,
  ) async {
    final id = await _goal(tester, goals, moves: [30000]);
    final router = GoRouter(
      initialLocation: '/goals/$id',
      routes: [
        GoRoute(
          path: '/goals/:id/edit',
          builder: (_, s) => GoalEditScreen(goalId: s.pathParameters['id']),
        ),
        GoRoute(
          path: '/goals/:id',
          builder: (_, s) => GoalDetailScreen(goalId: s.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, db, null, router: router);
    await _settle(tester);

    expect(find.text('Back'), findsOneWidget, reason: '#12: not a page name');
    await tester.tap(find.text('Edit'));
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    expect(find.text('Edit goal'), findsOneWidget);

    await tester.ensureVisible(find.text('Archive goal'));
    await tester.tap(find.text('Archive goal'));
    // The archive write is real async work, so the pop starts only after real time passes;
    // then the edit page fades out. Wait for both, or the next tap lands on the fading page.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 800));
    await _settle(tester);

    // Back on the goal, not stranded on a list with nowhere to go.
    expect(find.textContaining('Archived. Its money stays set aside'), findsOneWidget);
    final add = tester.widget<AkPrimaryButton>(find.widgetWithText(AkPrimaryButton, 'Add to goal'));
    expect(add.onPressed, isNull, reason: 'an archived goal takes no new money');

    // Called directly: the link is under a fading page for a moment after Archive.
    tester.widget<AkTextLink>(find.widgetWithText(AkTextLink, 'Unarchive')).onTap!();
    await _settle(tester);
    final goal = await tester.runAsync(() => goals.watchById(id).first);
    expect(goal!.archivedAt, isNull);
    await _leave(tester);
  });

  testWidgets('#3 with Hide amounts on, the goal list and detail show no figures', (tester) async {
    final id = await _goal(tester, goals, moves: [40000]);
    final hide = {PrivacyKeys.hideAmounts.name: '1'};

    await _pump(tester, db, const GoalsScreen(), stored: hide);
    await _settle(tester);
    expect(find.text('School fees'), findsOneWidget);
    expect(find.textContaining('40,000'), findsNothing);
    expect(find.textContaining('100,000'), findsNothing);

    // A fresh scope: Riverpod keeps the first overrides when the same scope rebuilds.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, db, GoalDetailScreen(goalId: id), stored: hide);
    await _settle(tester);
    expect(find.text('School fees'), findsOneWidget);
    expect(find.textContaining('40,000'), findsNothing);
    expect(find.textContaining('100,000'), findsNothing);
    expect(find.textContaining('60,000'), findsNothing, reason: 'the amount to go');
    await _leave(tester);
  });

  testWidgets('#6 a goal whose date has passed can still be renamed', (tester) async {
    final id = await _goal(
      tester,
      goals,
      name: 'Rent',
      target: 50000,
      targetDay: 20260301,
      on: DateTime(2026),
    );
    await _pump(tester, db, GoalEditScreen(goalId: id));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Rent for March');
    await tester.pump();
    await tester.tap(find.text('Save goal'));
    await _settle(tester);

    expect(find.textContaining('The date is in the past'), findsNothing);
    final goal = await tester.runAsync(() => goals.watchById(id).first);
    expect(goal!.name, 'Rent for March');
    await _leave(tester);
  });

  testWidgets('#8 Take out shows what each account holds for the goal', (tester) async {
    final id = await _goal(tester, goals, moves: [30000]);
    await _pump(tester, db, GoalDetailScreen(goalId: id));
    await _settle(tester);

    await tester.tap(find.text('Take out'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Back to account'), findsOneWidget);
    expect(find.text('MTN MoMo · 30,000'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('#9 a long history shows the newest moves and Show all for the rest', (tester) async {
    // 13 small moves on a big target: no milestone rows, so 13 rows in all.
    final id = await _goal(tester, goals, target: 1000000, moves: List.filled(13, 1000));
    await _pump(tester, db, GoalDetailScreen(goalId: id), height: 2400);
    await _settle(tester);

    final link = find.text('Show all 13');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    expect(find.text('Show fewer'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('a goal whose date has passed says so, not a weekly amount for that date', (
    tester,
  ) async {
    final id = await _goal(
      tester,
      goals,
      name: 'Rent',
      target: 50000,
      targetDay: 20260301,
      moves: [10000],
      on: DateTime(2026),
    );
    await _pump(tester, db, GoalDetailScreen(goalId: id), height: 2400);
    await _settle(tester);

    expect(find.text('The date passed on 1 March 2026. UGX 40,000 to go.'), findsOneWidget);
    expect(find.textContaining('a week to reach it by'), findsNothing);
    await _leave(tester);
  });

  testWidgets('the move sheet recovers from an unexpected error and lets the person retry', (
    tester,
  ) async {
    final id = await _goal(tester, goals);
    await _pump(
      tester,
      db,
      GoalDetailScreen(goalId: id),
      height: 2400,
      overrides: [goalRepositoryProvider.overrideWithValue(_FailingGoals(db))],
    );
    await _settle(tester);

    await tester.tap(find.text('Add to goal'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '20000');
    await tester.pump();
    tester.widget<AkPrimaryButton>(find.widgetWithText(AkPrimaryButton, 'Set aside')).onPressed!();
    await _settle(tester);

    expect(find.text('That could not be saved. Try again.'), findsOneWidget);
    expect(
      tester.widget<AkPrimaryButton>(find.widgetWithText(AkPrimaryButton, 'Set aside')).onPressed,
      isNotNull,
      reason: 'the button comes back on so the person can try again',
    );
    await _leave(tester);
  });

  testWidgets('setting aside more than is free in the account warns but still allows it', (
    tester,
  ) async {
    // MTN MoMo holds 50,000, and another goal already has 30,000 of it: 20,000 is free.
    await tester.runAsync(
      () => withClock(
        Clock.fixed(_today),
        () => AccountRepository(db).setBalanceToday('acct.mtn', 50000),
      ),
    );
    await _goal(tester, goals, name: 'Phone', moves: [30000]);
    final id = await _goal(tester, goals);
    await _pump(tester, db, GoalDetailScreen(goalId: id), height: 2400);
    await _settle(tester);

    await tester.tap(find.text('Add to goal'));
    await tester.pump(const Duration(milliseconds: 400));
    // The sheet loads its accounts, entries and goal moves when it opens.
    await _settle(tester);
    // No account tapped: the sheet starts on the one Add opens on, MTN MoMo in the seed data.
    await tester.enterText(find.byType(TextField).first, '30000');
    await tester.pump();
    expect(find.textContaining('free in MTN MoMo (UGX 20,000)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '10000');
    await tester.pump();
    expect(find.textContaining('free in MTN MoMo'), findsNothing);
    await _leave(tester);
  });
}
