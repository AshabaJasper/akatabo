import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/calendar/calendar_screen.dart';
import 'package:akatabo/features/calendar/period_cards.dart';
import 'package:akatabo/features/goals/goals_providers.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

/// Serves fixed rows for whatever period Calendar asks for.
class _PeriodRepo extends TransactionRepository {
  _PeriodRepo(this.rows) : super(AppDatabase(NativeDatabase.memory()));

  final List<Transaction> rows;

  @override
  Stream<List<Transaction>> watchIn(Period period) => Stream.value([
    for (final r in rows)
      if (period.containsDay(r.localDay)) r,
  ]);
}

final _now = DateTime(2026, 11, 19, 9, 14);

/// The drawn November, in thousands, for the 1st to the 19th.
const _drawn = [38, 48, 39, 41, 45, 62, 115, 36, 44, 40, 38, 46, 60, 87, 30, 398, 34, 30, 53];

final _rows = [
  for (var i = 0; i < _drawn.length; i++)
    txRow(
      id: 'n$i',
      amount: _drawn[i] * 1000,
      description: 'Day ${i + 1}',
      at: DateTime(2026, 11, i + 1, i == 18 ? 8 : 12),
    ),
  txRow(id: 'oct', amount: 70000, at: DateTime(2026, 10, 12, 10)),
];

/// Never answers, like a period whose rows are still loading.
class _SilentRepo extends TransactionRepository {
  _SilentRepo() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Stream<List<Transaction>> watchIn(Period period) => StreamController<List<Transaction>>().stream;
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  TransactionRepository? repo,
  DateTime? now,
  List<Goal> goals = const [],
  List<GoalMove> moves = const [],
  Stream<List<GoalMove>>? movesStream,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        appNowProvider.overrideWithValue(now ?? _now),
        periodCalculatorProvider.overrideWithValue(const PeriodCalculator()),
        transactionRepositoryProvider.overrideWithValue(repo ?? _PeriodRepo(_rows)),
        allCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(const <Account>[])),
        goalsProvider.overrideWith((ref) => Stream.value(goals)),
        allGoalMovesProvider.overrideWith((ref) => movesStream ?? Stream.value(moves)),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const CalendarScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('while a period loads it shows no zero total and no empty message', (tester) async {
    await _pump(tester, repo: _SilentRepo());
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.textContaining('UGX 0'), findsNothing);
    expect(find.textContaining('Nothing'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('UGX 0')), findsNothing);
  });

  testWidgets('Day view counts hours begun since the app opened', (tester) async {
    // The app opened at 09:00; it is now 11:30 and an entry was added at 11:05.
    final rows = [txRow(id: 'late', amount: 7000, at: DateTime(2026, 11, 19, 11, 5))];
    await withClock(Clock.fixed(DateTime(2026, 11, 19, 11, 30)), () async {
      await _pump(tester, repo: _PeriodRepo(rows), now: DateTime(2026, 11, 19, 9));
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
    });
    expect(find.bySemanticsLabel(RegExp(r'^From 11:00, UGX 7,000')), findsOneWidget);
    expect(find.bySemanticsLabel('From 11:00, not yet'), findsNothing);
    expect(find.bySemanticsLabel('From 10:00, not yet'), findsNothing);
  });

  testWidgets('Month opens on this month with today chosen and its total', (tester) async {
    await _pump(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('UGX 1,284,000 out so far'), findsOneWidget);
    expect(find.bySemanticsLabel('Thursday 19 November, UGX 53,000 out'), findsOneWidget);
    expect(find.bySemanticsLabel('Friday 20 November, not yet'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Thursday 19 November, UGX 53,000 out\. See')),
      findsOneWidget,
    );
  });

  testWidgets('a past day with nothing spent shows no figure but says so', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Earlier'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing, reason: 'no column of zeros');
    expect(find.bySemanticsLabel('Thursday 1 October, UGX 0 out'), findsOneWidget);
  });

  testWidgets('a day total takes the money-out colour, but UGX 0 stays ink', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Monday 16 November, UGX 398,000 out'));
    await tester.pump();
    final colours = tester.element(find.text('UGX 398,000')).colors;
    expect(tester.widget<Text>(find.text('UGX 398,000')).style?.color, colours.moneyOut);

    await tester.tap(find.bySemanticsLabel('Earlier'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Thursday 1 October, UGX 0 out'));
    await tester.pump();
    expect(tester.widget<Text>(find.text('UGX 0')).style?.color, colours.ink);
  });

  testWidgets('tapping a day shows its total; days to come cannot be chosen', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Monday 16 November, UGX 398,000 out'));
    await tester.pump();
    expect(find.text('UGX 398,000'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Friday 20 November, not yet'));
    await tester.pump();
    expect(find.text('UGX 398,000'), findsOneWidget, reason: 'the card did not move');
  });

  testWidgets('Later is off in the current month; Earlier steps back a month', (tester) async {
    await _pump(tester);
    final later = tester.getSemantics(find.bySemanticsLabel('Later'));
    expect(later.flagsCollection.isEnabled, Tristate.isFalse);

    await tester.tap(find.bySemanticsLabel('Earlier'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('UGX 70,000 out'), findsOneWidget, reason: 'a past month is not "so far"');
  });

  testWidgets('each period has its own view', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('15 to 21 November'), findsOneWidget);
    expect(find.bySemanticsLabel('Monday 16 November, UGX 398,000 out'), findsOneWidget);
    expect(find.bySemanticsLabel('Saturday 21 November, not yet'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Thursday 19 November'), findsWidgets);
    expect(find.text('Day 19'), findsOneWidget, reason: "the day's entries are listed");

    await tester.tap(find.text('3 months'));
    await tester.pumpAndSettle();
    expect(find.text('October to December 2026'), findsOneWidget);
    expect(find.textContaining('The busiest week was'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);
    expect(find.bySemanticsLabel('December 2026, not yet'), findsOneWidget);
    expect(
      find.text('The highest, lowest and usual month appear once two months end.'),
      findsOneWidget,
      reason: 'only October has ended with entries, and November is current',
    );
  });

  group('cards under each view', () {
    Goal goal() => Goal(
      id: 'g1',
      createdAt: _now,
      updatedAt: _now,
      name: 'Phone',
      iconKey: 'phone',
      colourToken: 'cat-teal',
      target: 900000,
      remindEvery: GoalRemind.off,
      sortOrder: 0,
    );
    GoalMove move(String id, int amount, DateTime at) => GoalMove(
      id: id,
      createdAt: at,
      updatedAt: at,
      goalId: 'g1',
      accountId: 'acct.mtn',
      amount: amount,
      occurredAt: at,
      localDay: at.year * 10000 + at.month * 100 + at.day,
    );

    testWidgets('Month: money in and out, the change on October, and the top categories', (
      tester,
    ) async {
      await _pump(tester);
      final money = find.text('Spent and received');
      await tester.scrollUntilVisible(money, 200);
      expect(money, findsOneWidget);
      expect(find.bySemanticsLabel('Out, UGX 1,284,000'), findsOneWidget);
      expect(find.text('UGX 1,284,000 more out than in so far.'), findsOneWidget);
      // November 1 to 19 against October 1 to 19, which had 70,000.
      // 1,284,000 is over 18 times 70,000: said as a multiple, not "1734% more".
      expect(find.text('About 18 times as much out as the same days of October.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Top categories'), 200);
      expect(find.text('Top categories'), findsOneWidget);
    });

    testWidgets('every period shows the cards and the page scrolls', (tester) async {
      await _pump(tester);
      for (final kind in ['Day', 'Week', '3 months', 'Year']) {
        await tester.scrollUntilVisible(find.text(kind), -200);
        await tester.tap(find.text(kind));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Spent and received'), 200);
        expect(find.text('Spent and received'), findsOneWidget, reason: kind);
      }
    });

    testWidgets('a finished period compares with the whole period before', (tester) async {
      await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Spent and received'), 200);
      // October against all of September, which had nothing.
      expect(
        find.text('Nothing went out in September, so there is nothing to compare with.'),
        findsOneWidget,
      );
      expect(find.text('UGX 70,000 more out than in.'), findsOneWidget, reason: 'not "so far"');
    });

    testWidgets('Savings shows goal money set aside in the period, only with goals', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Savings'), findsNothing, reason: 'no goals yet');
      await tester.pumpWidget(const SizedBox());

      await _pump(
        tester,
        goals: [goal()],
        moves: [
          move('m1', 50000, DateTime(2026, 11, 3, 9)),
          move('m2', -10000, DateTime(2026, 11, 10, 9)),
          move('m3', 99000, DateTime(2026, 10, 30, 9)),
        ],
      );
      await tester.scrollUntilVisible(find.text('Savings'), 200);
      expect(find.text('UGX 40,000 set aside for goals this month.'), findsOneWidget);
    });

    testWidgets('a past day with nothing in or out shows no money cards', (tester) async {
      // Entries run to the 19th; with today the 21st, the 20th is past and empty.
      await _pump(tester, now: DateTime(2026, 11, 21, 9));
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await tester.pumpAndSettle();
      expect(find.text('Friday 20 November'), findsWidgets);
      expect(find.text('Spent and received'), findsNothing);
    });

    // Bug review, 25 Nov 2026. Each test names the bug it guards.

    testWidgets('#1 a finished month is compared with all of the month before', (tester) async {
      // October has 70,000 on the 12th and 100,000 on the 31st. November (30 days) once
      // ended used to be set against October 1 to 30 only, leaving the 31st out.
      await _pump(
        tester,
        now: DateTime(2026, 12, 5, 9),
        repo: _PeriodRepo([
          ..._rows,
          txRow(id: 'o31', amount: 100000, at: DateTime(2026, 10, 31, 12)),
        ]),
      );
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Spent and received'), 200);
      // 1,284,000 against 170,000 is about 8 times; against 70,000 it would say 18.
      expect(find.text('About 8 times as much out as October.'), findsOneWidget);
    });

    test('#2 the Fees and tax row opens Fees, other rows their category', () {
      expect(categoryRoute(DefaultIds.fees), Routes.fees);
      expect(categoryRoute(DefaultIds.food), Routes.category(DefaultIds.food));
    });

    testWidgets('#3 #4 top category rows are buttons this month, plain rows in other periods', (
      tester,
    ) async {
      await _pump(tester);
      final row = find.bySemanticsLabel(RegExp(r'^Other, '));
      await tester.scrollUntilVisible(row, 200);
      expect(
        tester.getSemantics(row),
        isSemantics(isButton: true, hasTapAction: true),
        reason: 'this month: it opens the category page',
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.scrollUntilVisible(find.text('Year'), -200);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(row, 200);
      expect(
        tester.getSemantics(row),
        isSemantics(isButton: false, hasTapAction: false),
        reason: "the category page shows this month, not the year's figures",
      );
    });

    testWidgets('#6 while goal moves fail to load, Savings says nothing rather than zero', (
      tester,
    ) async {
      await _pump(
        tester,
        goals: [goal()],
        movesStream: Stream<List<GoalMove>>.error(StateError('read failed')),
      );
      await tester.scrollUntilVisible(find.text('Top categories'), 200);
      expect(find.textContaining('No money set aside'), findsNothing);
      expect(find.text('Savings'), findsNothing);
    });
  });

  // The design system's floor is 44px (WCAG 2.5.5, Apple's 44pt). Day cells are 45px wide
  // as drawn, under Android's own 48dp check, so this screen is held to 44px.
  testWidgets('every control is a labelled 44px target', (tester) async {
    await _pump(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  for (final b in Brightness.values) {
    testWidgets('calendar golden, ${b.name}', (tester) async {
      await _pump(tester, brightness: b);
      await expectLater(
        find.byType(CalendarScreen),
        matchesGoldenFile('goldens/calendar_${b.name}.png'),
      );
    });
  }
}
