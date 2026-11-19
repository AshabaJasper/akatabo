import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/add/add_screen.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

/// Records what Add would save instead of writing to a database, so the widget test
/// does not depend on database timing inside the test's fake clock.
class RecordingTransactionRepository extends TransactionRepository {
  RecordingTransactionRepository() : super(AppDatabase(NativeDatabase.memory()));

  final drafts = <TransactionDraft>[];

  @override
  Future<String> add(TransactionDraft draft) async {
    drafts.add(draft);
    return 'saved-${drafts.length}';
  }
}

/// A database that refuses every insert, as a full disk would.
class FailingTransactionRepository extends RecordingTransactionRepository {
  @override
  Future<String> add(TransactionDraft draft) => Future.error(StateError('disk full'));
}

final _now = DateTime(2026, 11, 19, 9, 14);

final _accounts = [
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true),
  accountRow(id: DefaultIds.cash, name: 'Cash', colourToken: 'acct-cash'),
];

final _spending = [
  categoryRow(id: DefaultIds.food, name: 'Food and shopping'),
  categoryRow(
    id: DefaultIds.transport,
    name: 'Transport',
    iconKey: 'bus',
    colourToken: 'cat-amber',
  ),
];

final _income = [
  categoryRow(
    id: DefaultIds.salary,
    name: 'Salary',
    iconKey: 'work',
    colourToken: 'cat-blue',
    kind: CategoryKind.income,
  ),
];

/// Opens Add the way Home does (pushed over the tabs), with every list fed from fixtures.
Future<RecordingTransactionRepository> _pumpAdd(
  WidgetTester tester, {
  RecordingTransactionRepository? repository,
  Brightness brightness = Brightness.light,
  Map<String, String> settings = const {},
  double height = 844,
  Clock? clock,
}) async {
  tester.view
    ..physicalSize = Size(390, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = repository ?? RecordingTransactionRepository();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        spendingCategoriesProvider.overrideWith((ref) => Stream.value(_spending)),
        incomeCategoriesProvider.overrideWith((ref) => Stream.value(_income)),
        enabledAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        transactionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const AddScreen())),
                child: const Text('open add'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Add reads the time when it opens, for its "When" label.
  await withClock(clock ?? Clock.fixed(_now), () async {
    await tester.tap(find.text('open add'));
    await tester.pumpAndSettle();
  });
  return repo;
}

Future<void> _enterAmount(WidgetTester tester, String amount) async {
  await tester.enterText(find.byType(TextField).at(0), amount);
  await tester.pump();
}

void main() {
  testWidgets('saving with no amount says why and saves nothing', (tester) async {
    final repo = await _pumpAdd(tester);
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);
    expect(find.text('Choose a category.'), findsOneWidget);
    expect(repo.drafts, isEmpty);
  });

  testWidgets('an amount, a few words and one category save and close Add', (tester) async {
    final repo = await _pumpAdd(tester);
    await _enterAmount(tester, '45000');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(repo.drafts, hasLength(1));
    final draft = repo.drafts.single;
    expect(draft.direction, Direction.moneyOut);
    expect(draft.amount, 45000);
    expect(draft.description, 'Groceries');
    expect(draft.categoryId, DefaultIds.food);
    expect(draft.accountId, DefaultIds.mtn, reason: 'the default account is preselected');
    expect(draft.fee, 0);
    expect(find.text('Save transaction'), findsNothing, reason: 'Add closed after saving');
  });

  testWidgets('the entry is stamped with the moment of saving, not when Add opened', (
    tester,
  ) async {
    final repo = await _pumpAdd(tester);
    await _enterAmount(tester, '8000');
    await tester.tap(find.bySemanticsLabel('Transport'));
    await tester.pump();
    final later = DateTime(2026, 11, 19, 15, 40);
    await withClock(Clock.fixed(later), () async {
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
    });
    expect(repo.drafts.single.occurredAt, later);
  });

  testWidgets('a failed save says so, keeps the entry and lets the person try again', (
    tester,
  ) async {
    await _pumpAdd(tester, repository: FailingTransactionRepository());
    await _enterAmount(tester, '45000');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>(), reason: 'the error is still reported');
    expect(find.text('This entry could not be saved. Try again.'), findsOneWidget);
    expect(find.text('Save transaction'), findsOneWidget, reason: 'not stuck on Saving');
    expect(find.text('45,000'), findsOneWidget, reason: 'what was typed is kept');
  });

  testWidgets('a fee is kept with the entry and counts towards money out', (tester) async {
    final repo = await _pumpAdd(tester);
    await _enterAmount(tester, '45000');
    await tester.enterText(find.byType(TextField).at(2), '1000');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(repo.drafts.single.fee, 1000);
    expect(
      moneyOutOf(txRow(amount: repo.drafts.single.amount, fee: repo.drafts.single.fee)),
      46000,
    );
  });

  testWidgets('money in offers income categories and no fee', (tester) async {
    final repo = await _pumpAdd(tester);
    await tester.tap(find.text('Money in'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Salary'), findsOneWidget);
    expect(find.bySemanticsLabel('Food and shopping'), findsNothing);
    expect(find.text('Fee, if any'), findsNothing);

    await _enterAmount(tester, '250000');
    await tester.tap(find.bySemanticsLabel('Salary'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    final draft = repo.drafts.single;
    expect(draft.direction, Direction.moneyIn);
    expect(draft.categoryId, DefaultIds.salary);
    expect(draft.fee, 0);
  });

  testWidgets('move money has no category and needs two different accounts', (tester) async {
    final repo = await _pumpAdd(tester);
    await tester.tap(find.text('Move money'));
    await tester.pumpAndSettle();
    expect(find.text('CATEGORY'), findsNothing);
    expect(find.text('TO'), findsOneWidget);

    await _enterAmount(tester, '100000');
    // The "To" group opens on the other account, so pick the same one by tapping the
    // second MTN chip (the "To" row sits below "From").
    await tester.tap(find.text('MTN MoMo').last);
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Choose two different accounts.'), findsOneWidget);
    expect(repo.drafts, isEmpty);

    await tester.tap(find.text('Cash').last);
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    final draft = repo.drafts.single;
    expect(draft.direction, Direction.transfer);
    expect(draft.accountId, DefaultIds.mtn);
    expect(draft.toAccountId, DefaultIds.cash);
    expect(draft.categoryId, isNull);
  });

  testWidgets('categories are announced as buttons with their names', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpAdd(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Food and shopping')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('each kind fits on one line beside the close button', (tester) async {
    await _pumpAdd(tester);
    for (final label in ['Money out', 'Money in', 'Move money']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final fontSize = paragraph.text.style?.fontSize ?? 14;
      // One line is under twice the font size tall; two lines are not.
      expect(paragraph.size.height, lessThan(fontSize * 2), reason: '$label must not wrap');
    }
  });

  group('when', () {
    // Tall enough that the "When" field at the bottom of the list is built.
    const tall = 1400.0;
    Finder whenField() => find.bySemanticsLabel(RegExp(r'^When, '));

    Future<void> fillMinimum(WidgetTester tester) async {
      await _enterAmount(tester, '8000');
      await tester.tap(find.bySemanticsLabel('Transport'));
      await tester.pump();
    }

    testWidgets('reads "Today" and the time Add opened until another moment is chosen', (
      tester,
    ) async {
      await _pumpAdd(tester, height: tall);
      expect(find.text('Today, 09:14'), findsOneWidget);
      expect(find.text('Use the time of saving'), findsNothing);
    });

    testWidgets('the date picker runs from 1 January last year to today, in the app theme', (
      tester,
    ) async {
      await _pumpAdd(tester, height: tall);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
      });
      final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialog.firstDate, DateTime(2025));
      expect(dialog.lastDate, DateTime(2026, 11, 19));
      expect(dialog.currentDate, DateTime(2026, 11, 19));
      final theme = Theme.of(tester.element(find.byType(DatePickerDialog))).datePickerTheme;
      final colours = Theme.of(tester.element(find.byType(AddScreen))).extension<AkColors>()!;
      expect(theme.backgroundColor, colours.tokens.surface);
      expect(theme.dayBackgroundColor?.resolve({WidgetState.selected}), colours.tokens.brand);
    });

    testWidgets('left open, the unchosen time keeps up with the clock, past midnight too', (
      tester,
    ) async {
      var time = DateTime(2026, 11, 19, 23, 58);
      await _pumpAdd(tester, height: tall, clock: Clock(() => time));
      expect(find.text('Today, 23:58'), findsOneWidget);
      time = DateTime(2026, 11, 20, 0, 1);
      await tester.pump(const Duration(seconds: 16));
      expect(find.text('Today, 00:01'), findsOneWidget, reason: 'not "Yesterday, 23:58"');
    });

    testWidgets('the date picker writes dates as the app does and starts weeks on the setting', (
      tester,
    ) async {
      await _pumpAdd(
        tester,
        height: tall,
        settings: {SettingKeys.weekStartsOn.name: '${DateTime.monday}'},
      );
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
      });
      expect(find.text('Thu 19 Nov'), findsOneWidget);
      final words = MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)));
      expect(words.firstDayOfWeekIndex, 1, reason: 'Monday first');
      expect(words.formatCompactDate(DateTime(2026, 11, 7)), '07/11/2026');
      expect(words.parseCompactDate('17/11/2026'), DateTime(2026, 11, 17));
      expect(words.parseCompactDate('31/02/2026'), isNull);
      expect(words.parseCompactDate('11/17/2026'), isNull, reason: 'not month first');
    });

    testWidgets('a chosen day and time are shown and saved, with their own day', (tester) async {
      final repo = await _pumpAdd(tester, height: tall);
      await fillMinimum(tester);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        await tester.tap(find.text('17'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        // The time dialog opens on the current time; switch to typing and set 14:30.
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.at(0), '14');
        await tester.enterText(fields.at(1), '30');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });

      expect(find.text('Tuesday 17 November, 14:30'), findsOneWidget);
      await withClock(Clock.fixed(DateTime(2026, 11, 19, 15)), () async {
        await tester.tap(find.text('Save transaction'));
        await tester.pumpAndSettle();
      });
      expect(repo.drafts.single.occurredAt, DateTime(2026, 11, 17, 14, 30));
    });

    testWidgets('a time later than now today is refused and the old moment kept', (tester) async {
      await _pumpAdd(tester, height: tall);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK')); // today, already chosen
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        final fields = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.at(0), '18');
        await tester.enterText(fields.at(1), '00');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      });
      expect(find.text('That time has not come yet. Choose a time up to now.'), findsOneWidget);
      expect(find.text('Today, 09:14'), findsOneWidget);
    });

    testWidgets('cancelling keeps the time of saving, and "Use the time of saving" goes back', (
      tester,
    ) async {
      final repo = await _pumpAdd(tester, height: tall);
      await fillMinimum(tester);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Today, 09:14'), findsOneWidget);

      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        await tester.tap(find.text('18'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK')); // the time dialog, keeping 09:14
        await tester.pumpAndSettle();
      });
      expect(find.text('Yesterday, 09:14'), findsOneWidget);
      await tester.tap(find.text('Use the time of saving'));
      await tester.pump();
      expect(find.text('Today, 09:14'), findsOneWidget);

      final later = DateTime(2026, 11, 19, 10, 2);
      await withClock(Clock.fixed(later), () async {
        await tester.tap(find.text('Save transaction'));
        await tester.pumpAndSettle();
      });
      expect(repo.drafts.single.occurredAt, later);
    });

    testWidgets('"When" is one button for screen readers, 48px tall', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpAdd(tester, height: tall);
      expect(
        tester.getSemantics(whenField()),
        isSemantics(isButton: true, hasTapAction: true, label: 'When, Today, 09:14'),
      );
      expect(tester.getSize(whenField()).height, greaterThanOrEqualTo(AkSize.input));
      handle.dispose();
    });
  });

  testWidgets('Add starts as the kind chosen in General settings', (tester) async {
    final repo = await _pumpAdd(tester, settings: {'general.newEntryDirection': 'moneyIn'});
    expect(find.bySemanticsLabel('Salary'), findsOneWidget);
    await _enterAmount(tester, '250000');
    await tester.tap(find.bySemanticsLabel('Salary'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(repo.drafts.single.direction, Direction.moneyIn);
  });

  for (final b in Brightness.values) {
    testWidgets('add golden, ${b.name}', (tester) async {
      await _pumpAdd(tester, brightness: b);
      await _enterAmount(tester, '45000');
      await tester.enterText(find.byType(TextField).at(1), 'Groceries, Nakasero market');
      await tester.tap(find.bySemanticsLabel('Food and shopping'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(AddScreen), matchesGoldenFile('goldens/add_${b.name}.png'));
    });
  }
}
