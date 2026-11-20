import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/calendar/calendar_screen.dart';
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
