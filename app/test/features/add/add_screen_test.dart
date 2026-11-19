import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
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
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = repository ?? RecordingTransactionRepository();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
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
  await tester.tap(find.text('open add'));
  await tester.pumpAndSettle();
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
