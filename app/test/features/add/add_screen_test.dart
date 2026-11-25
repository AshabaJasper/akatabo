import 'dart:async';

import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/icons/ak_icon.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/settings/remembered_rates.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/add/add_screen.dart';
import 'package:akatabo/services/notifications/budget_warning.dart';
import 'package:akatabo/widgets/ak_month_grid.dart';
import 'package:akatabo/widgets/ak_pickers.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
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

  /// Entries Add can open for editing or copying.
  final stored = <String, Transaction>{};

  /// Edits, as (id, draft).
  final updates = <(String, TransactionDraft)>[];

  @override
  Future<String> add(TransactionDraft draft) async {
    drafts.add(draft);
    return 'saved-${drafts.length}';
  }

  @override
  Future<Transaction?> byId(String id) async => stored[id];

  @override
  Future<void> update(String id, TransactionDraft draft) async => updates.add((id, draft));
}

/// A database that refuses every insert, as a full disk would.
class FailingTransactionRepository extends RecordingTransactionRepository {
  @override
  Future<String> add(TransactionDraft draft) => Future.error(StateError('disk full'));
}

/// Keeps the settings Add writes, such as the rate remembered for a currency.
class RecordingSettingsRepository extends SettingsRepository {
  RecordingSettingsRepository() : super(AppDatabase(NativeDatabase.memory()));

  final written = <String, String>{};

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async => written[key.name] = '$value';
}

/// Saves only when [finish] completes, so a test can close Add mid-save.
class SlowTransactionRepository extends RecordingTransactionRepository {
  final finish = Completer<void>();

  @override
  Future<String> add(TransactionDraft draft) async {
    await finish.future;
    return super.add(draft);
  }
}

/// Records which saved entries Add hands to the budget warning.
class RecordingBudgetWarner extends BudgetWarner {
  RecordingBudgetWarner(super.ref, this.checked);
  final List<String> checked;

  @override
  Future<void> afterSave(String transactionId, {Transaction? previous}) async =>
      checked.add(transactionId);
}

final _now = DateTime(2026, 11, 19, 9, 14);

final _accounts = [
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true),
  accountRow(id: DefaultIds.cash, name: 'Cash', colourToken: 'acct-cash', askFeeEachTime: false),
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
  RecordingSettingsRepository? settingsRepository,
  Brightness brightness = Brightness.light,
  Map<String, String> settings = const {},
  double height = 844,
  Clock? clock,
  List<String>? warned,
  AddScreen screen = const AddScreen(),
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
        if (settingsRepository != null)
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
        if (warned != null)
          budgetWarnerProvider.overrideWith((ref) => RecordingBudgetWarner(ref, warned)),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
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

  testWidgets('the amount problem sits on the amount field, not repeated in the list', (
    tester,
  ) async {
    await _pumpAdd(tester);
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    final amount = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0'),
    );
    expect(amount.decoration?.errorText, 'Enter an amount above zero.');
    expect(find.text('Enter an amount above zero.'), findsOneWidget, reason: 'shown once');
  });

  testWidgets('a foreign amount with no rate says so under the rate box', (tester) async {
    await _pumpAdd(tester, height: 1100);
    await tester.tap(find.text('UGX')); // the currency chip
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await _enterAmount(tester, '100');
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the USD amount and its rate.'), findsOneWidget);
    expect(
      find.text('Enter the foreign amount and its rate.'),
      findsNothing,
      reason: 'one message',
    );
  });

  testWidgets('a field problem goes once that field is put right', (tester) async {
    await _pumpAdd(tester);
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above zero.'), findsOneWidget);

    await _enterAmount(tester, '45000');
    final amount = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0'),
    );
    expect(amount.decoration?.errorText, isNull, reason: 'not marking 45,000 as wrong');
    expect(find.text('Enter an amount above zero.'), findsNothing);
    expect(find.text('Choose a category.'), findsOneWidget, reason: 'other problems stay');
  });

  testWidgets('"two different accounts" goes once another To account is chosen', (tester) async {
    await _pumpAdd(tester);
    await tester.tap(find.text('Move money'));
    await tester.pumpAndSettle();
    await _enterAmount(tester, '100000');
    await tester.tap(find.text('MTN MoMo').last);
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Choose two different accounts.'), findsOneWidget);

    await tester.tap(find.text('Cash').last);
    await tester.pump();
    expect(find.text('Choose two different accounts.'), findsNothing);
  });

  testWidgets('Save brings a field problem into view and says it', (tester) async {
    // Short enough that the amount scrolls with the form instead of staying pinned.
    await _pumpAdd(tester, height: 480);
    tester.takeAnnouncements();
    // The list builds Save only once it is scrolled near it.
    await tester.dragUntilVisible(
      find.text('Save transaction'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final amountField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0',
    );
    // Precondition: the amount has scrolled so far that the list no longer builds it.
    expect(amountField, findsNothing);

    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    final error = tester.getRect(find.text('Enter an amount above zero.'));
    expect(error.top, greaterThanOrEqualTo(0), reason: 'the problem is on screen');
    expect(error.bottom, lessThanOrEqualTo(480));
    expect(tester.takeAnnouncements().map((a) => a.message), ['Enter an amount above zero.']);
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

  testWidgets('a saved entry is handed to the budget warning; a failed one is not', (tester) async {
    final warned = <String>[];
    await _pumpAdd(tester, warned: warned);
    await _enterAmount(tester, '45000');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(warned, ['saved-1']);

    final none = <String>[];
    await _pumpAdd(tester, repository: FailingTransactionRepository(), warned: none);
    await _enterAmount(tester, '45000');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(none, isEmpty);
  });

  testWidgets('closed while saving, Add still hands the entry on without an error', (tester) async {
    final warned = <String>[];
    final repo = SlowTransactionRepository();
    await _pumpAdd(tester, repository: repo, warned: warned);
    await _enterAmount(tester, '45000');
    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pump();
    // Back, before the save finishes.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open add'), findsOneWidget);
    repo.finish.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(warned, ['saved-1']);
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

  testWidgets('a dollar payment is typed in dollars, saved in shillings, and its rate remembered', (
    tester,
  ) async {
    final repo = RecordingTransactionRepository();
    final settings = RecordingSettingsRepository();
    // Taller than the default, so the foreign fields and Save all fit without scrolling.
    await _pumpAdd(tester, repository: repo, settingsRepository: settings, height: 1100);

    await tester.tap(find.text('UGX')); // the currency chip
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await _enterAmount(tester, '100');
    // The rate field comes straight after the amount field (index 0).
    await tester.enterText(find.byType(TextField).at(1), '3720');
    await tester.pump();
    expect(find.text('= UGX 372,000'), findsOneWidget, reason: 'the live conversion');

    await tester.tap(find.bySemanticsLabel('Food and shopping'));
    await tester.pump();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    final draft = repo.drafts.single;
    expect(draft.amount, 372000, reason: 'saved as whole shillings');
    expect(draft.foreignCurrency, 'USD');
    expect(draft.foreignAmountMinor, 10000);
    expect(draft.rateMicros, 3720000000);
    expect(settings.written[rateSetting('USD').name], '3720000000', reason: 'rate remembered');
  });

  group('a decimal point in a shilling amount', () {
    Future<String> after(WidgetTester tester, String before, String next) async {
      await _pumpAdd(tester);
      if (before.isNotEmpty) await _enterAmount(tester, before);
      await tester.enterText(find.byType(TextField).at(0), next);
      await tester.pump();
      return tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text;
    }

    testWidgets('never joins the digits either side (5000.5 is not 50,005)', (tester) async {
      expect(await after(tester, '5000', '5,000.5'), '5,000');
    });

    testWidgets('a pasted figure with cents keeps its shillings', (tester) async {
      expect(await after(tester, '', '50,000.00'), '50,000');
    });

    testWidgets('a point that groups thousands is refused, not cut', (tester) async {
      expect(await after(tester, '', '1.500'), '', reason: 'cutting would make it 1');
    });
  });

  group('changing the currency', () {
    const rates = {'rate.USD': '3720000000', 'rate.KES': '28000000'};
    String rateText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text;
    Future<void> choose(WidgetTester tester, String chip, String option) async {
      await tester.tap(find.text(chip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('each foreign currency starts with its own rate, not the last one', (tester) async {
      await _pumpAdd(tester, settings: rates, height: 1100);
      await choose(tester, 'UGX', 'USD');
      expect(rateText(tester), '3,720');
      await choose(tester, 'USD', 'KES');
      expect(rateText(tester), '28', reason: 'the KES rate, not the dollar one');
      await choose(tester, 'KES', 'EUR');
      expect(rateText(tester), '', reason: 'no rate remembered for EUR');
    });

    testWidgets('back to shillings, a complete foreign amount becomes its shillings', (
      tester,
    ) async {
      await _pumpAdd(tester, settings: rates, height: 1100);
      await choose(tester, 'UGX', 'USD');
      await _enterAmount(tester, '100');
      await choose(tester, 'USD', 'UGX, Ugandan shilling');
      expect(find.text('372,000'), findsOneWidget);
    });

    testWidgets('shillings get a keyboard with no decimal key; a foreign amount gets one', (
      tester,
    ) async {
      await _pumpAdd(tester, height: 1100);
      TextInputType amountKeyboard() =>
          tester.widget<TextField>(find.byType(TextField).first).keyboardType;
      expect(amountKeyboard(), TextInputType.number);
      await choose(tester, 'UGX', 'USD');
      expect(amountKeyboard(), const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('saving an edit at an old rate leaves the remembered rate alone', (tester) async {
      final repo = RecordingTransactionRepository()
        ..stored['t1'] = txRow(id: 't1', amount: 360000, description: 'Licence').copyWith(
          foreignCurrency: const Value('USD'),
          foreignAmountMinor: const Value(10000),
          rateMicros: const Value(3600000000),
        );
      final settings = RecordingSettingsRepository();
      await _pumpAdd(
        tester,
        repository: repo,
        settingsRepository: settings,
        settings: rates,
        height: 1600,
        screen: const AddScreen(editId: 't1'),
      );
      await tester.pumpAndSettle();
      expect(rateText(tester), '3,600', reason: 'the entry keeps the rate it was saved with');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repo.updates.single.$2.rateMicros, 3600000000);
      expect(settings.written, isEmpty, reason: 'today\'s 3,720 is still the one remembered');
    });
  });

  group('"Ask for the fee each time"', () {
    // MTN MoMo asks for the fee; Cash does not (see _accounts).
    Finder feeUpFront() => find.text('FEE, IF ANY');

    testWidgets('an account that asks shows the fee box in the form', (tester) async {
      await _pumpAdd(tester);
      expect(feeUpFront(), findsOneWidget);
    });

    testWidgets('one that does not keeps it under More details, and a fee there is saved', (
      tester,
    ) async {
      final repo = await _pumpAdd(tester, height: 1400);
      await tester.tap(find.text('Cash'));
      await tester.pump();
      expect(feeUpFront(), findsNothing);

      await tester.tap(find.text('More details'));
      await tester.pump();
      expect(feeUpFront(), findsOneWidget);
      final fee = find.descendant(
        of: find.ancestor(of: feeUpFront(), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(fee, '500');
      await _enterAmount(tester, '20000');
      await tester.tap(find.bySemanticsLabel('Food and shopping'));
      await tester.pump();
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(repo.drafts.single.accountId, DefaultIds.cash);
      expect(repo.drafts.single.fee, 500);
    });

    testWidgets('a fee typed in the form stays in view when the account changes', (tester) async {
      await _pumpAdd(tester);
      await tester.enterText(find.byType(TextField).at(2), '1000');
      await tester.tap(find.text('Cash'));
      await tester.pump();
      expect(feeUpFront(), findsOneWidget);
      expect(find.text('1,000'), findsOneWidget);
    });

    testWidgets('moving money always shows its fee, even from an account that does not ask', (
      tester,
    ) async {
      await _pumpAdd(tester);
      await tester.tap(find.text('Move money'));
      await tester.pumpAndSettle();
      expect(find.text('FEE TO MOVE IT'), findsOneWidget, reason: 'from MTN MoMo');
      await tester.tap(find.text('Cash').first);
      await tester.pump();
      expect(find.text('FEE TO MOVE IT'), findsOneWidget, reason: 'from Cash too');
    });

    testWidgets('Edit fills the form and saves over the same entry, keeping its suggestion', (
      tester,
    ) async {
      final at = DateTime(2026, 11, 17, 18, 30);
      final repo = RecordingTransactionRepository()
        ..stored['t1'] =
            txRow(
              id: 't1',
              amount: 45000,
              description: 'Groceries',
              categoryId: DefaultIds.transport,
              fee: 500,
              note: 'Weekly shop',
              at: at,
            ).copyWith(
              suggestedCategoryId: const Value(DefaultIds.food),
              suggestionConfidence: const Value(0.8),
            );
      await _pumpAdd(
        tester,
        repository: repo,
        height: 1600,
        screen: const AddScreen(editId: 't1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('45,000'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '46,000');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.drafts, isEmpty, reason: 'no new entry');
      expect(repo.updates, hasLength(1));
      final (id, draft) = repo.updates.single;
      expect(id, 't1');
      expect(draft.amount, 46000);
      expect(draft.occurredAt, at, reason: 'the moment stays');
      expect(draft.categoryId, DefaultIds.transport);
      expect(draft.fee, 500);
      expect(draft.note, 'Weekly shop');
      expect(draft.suggestedCategoryId, DefaultIds.food, reason: 'the first suggestion is kept');
    });

    testWidgets('Add one like this starts a new entry from it, dated when it is saved', (
      tester,
    ) async {
      final repo = RecordingTransactionRepository()
        ..stored['t1'] = txRow(
          id: 't1',
          amount: 2000,
          description: 'Boda to work',
          categoryId: DefaultIds.transport,
          at: DateTime(2026, 11, 10, 8),
        );
      await _pumpAdd(
        tester,
        repository: repo,
        height: 1600,
        screen: const AddScreen(likeId: 't1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Boda to work'), findsOneWidget);
      expect(find.text('Save transaction'), findsOneWidget);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(find.text('Save transaction'));
        await tester.pumpAndSettle();
      });
      expect(repo.updates, isEmpty);
      expect(repo.drafts.single.amount, 2000);
      expect(repo.drafts.single.categoryId, DefaultIds.transport);
      expect(repo.drafts.single.occurredAt, _now);
    });

    testWidgets('an entry that cannot be opened for editing is never saved as a new one', (
      tester,
    ) async {
      final repo = RecordingTransactionRepository();
      await _pumpAdd(
        tester,
        repository: repo,
        height: 1600,
        screen: const AddScreen(editId: 'gone'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('That entry could not be opened. It may have been deleted.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).at(0), '5,000');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.drafts, isEmpty);
      expect(repo.updates, isEmpty);
    });

    testWidgets('the keyboard moving the amount keeps the same focused field', (tester) async {
      await _pumpAdd(tester);
      final field = find.descendant(
        of: find.bySemanticsLabel('Amount in shillings'),
        matching: find.byType(EditableText),
      );
      final before = tester.state<EditableTextState>(field);
      expect(before.widget.focusNode.hasFocus, isTrue, reason: 'Add opens on the amount');

      // A keyboard this tall leaves too little room, so the amount moves into the list.
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(field), same(before));
      expect(before.widget.focusNode.hasFocus, isTrue);

      // Closing the keyboard leaves focus where it is put, not pulled back by autofocus.
      before.widget.focusNode.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(field), same(before));
      expect(before.widget.focusNode.hasFocus, isFalse);
    });

    testWidgets('the kind and the amount stay in view while the form scrolls', (tester) async {
      await _pumpAdd(tester);
      final amountTop = tester.getTopLeft(find.bySemanticsLabel('Amount in shillings')).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.bySemanticsLabel('Amount in shillings')).dy, amountTop);
      expect(find.text('Money out'), findsOneWidget);
    });
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
      final dialog = tester.widget<AkDateDialog>(find.byType(AkDateDialog));
      expect(dialog.first, DateTime(2025));
      expect(dialog.last, DateTime(2026, 11, 19));
      expect(dialog.today, DateTime(2026, 11, 19));
      final colours = Theme.of(tester.element(find.byType(AddScreen))).extension<AkColors>()!;
      final box = tester.widget<Dialog>(
        find.descendant(of: find.byType(AkDateDialog), matching: find.byType(Dialog)),
      );
      expect(box.backgroundColor, colours.tokens.surface);
    });

    testWidgets('neither dialog draws a font icon, which showed as empty boxes', (tester) async {
      await _pumpAdd(tester, height: tall);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        expect(find.byType(Icon), findsNothing, reason: 'the date dialog');
        expect(find.byType(AkIcon), findsWidgets, reason: 'its arrows are vector icons');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.byType(Icon), findsNothing, reason: 'the time dialog');
      });
    });

    testWidgets('days after today are faded and cannot be chosen', (tester) async {
      await _pumpAdd(tester, height: tall);
      await withClock(Clock.fixed(_now), () async {
        await tester.tap(whenField());
        await tester.pumpAndSettle();
        await tester.tap(find.text('25'));
        await tester.pump();
      });
      expect(find.text('Thu 19 Nov'), findsOneWidget, reason: 'the 25th is not chosen');
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
      expect(find.text('November 2026'), findsOneWidget);
      final grid = tester.widget<AkMonthGrid>(find.byType(AkMonthGrid));
      expect(grid.weekStartsOn, DateTime.monday, reason: 'Monday first');
      // November 2026 starts on a Sunday: with Monday first, the 1st sits in the last column.
      final first = tester.getTopLeft(find.text('1'));
      final second = tester.getTopLeft(find.text('2'));
      expect(second.dy, greaterThan(first.dy), reason: 'the 2nd, a Monday, opens the next row');
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
        // The time dialog opens on the current time, ready to type; set 14:30.
        expect(find.byType(TimePickerDialog), findsOneWidget);
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
