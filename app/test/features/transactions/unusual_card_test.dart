import 'dart:convert';
import 'dart:io';

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
import 'package:akatabo/features/transactions/unusual_card.dart';
import 'package:akatabo/features/transactions/unusual_providers.dart';
import 'package:akatabo/smart/unusual/unusual_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/backup_seed.dart' show memoryDb;
import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

UnusualParams _params() => UnusualParams.fromJson(
  jsonDecode(File('assets/smart/unusual_params.json').readAsStringSync()) as Map<String, Object?>,
);

/// Thirty ordinary lunches at midday, then one lunch at fifty times the usual price.
final _rows = [
  txRow(id: 'big', amount: 250000, description: 'lunch', at: DateTime(2026, 11, 19, 12, 5)),
  for (var i = 1; i <= 30; i++)
    txRow(id: 'l$i', amount: 5000, description: 'lunch', at: DateTime(2026, 11, 19 - i, 12, 10)),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, String> settings = const {},
  Brightness brightness = Brightness.light,
  AppDatabase? db,
  List<Transaction>? rows,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final params = _params();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        appDatabaseProvider.overrideWithValue(db ?? memoryDb()),
        allTransactionsProvider.overrideWith((ref) => Stream.value(rows ?? _rows)),
        transactionByIdProvider('big').overrideWith((ref) => Stream.value((rows ?? _rows).first)),
        unusualParamsProvider.overrideWith((ref) async => params),
        allCategoriesProvider.overrideWith(
          (ref) => Stream.value([categoryRow(id: DefaultIds.food, name: 'Food and shopping')]),
        ),
        enabledAccountsProvider.overrideWith(
          (ref) =>
              Stream.value([accountRow(id: DefaultIds.mtn, name: 'MTN MoMo', isDefault: true)]),
        ),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const TransactionDetailScreen(id: 'big'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(TransactionDetailScreen)));
}

void main() {
  testWidgets('a much larger payment shows why, with its evidence', (tester) async {
    await _pump(tester);
    expect(find.byType(UnusualCard), findsOneWidget);
    expect(find.text('Unusual for you'), findsOneWidget);
    expect(
      find.text('It is about 50 times what you usually pay here (UGX 5,000).'),
      findsOneWidget,
    );
    expect(find.text('Compared with your 30 earlier Food and shopping entries.'), findsOneWidget);
  });

  testWidgets('"This was me" hides the card at once and saves the answer on the entry', (
    tester,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await tester.runAsync(() => db.into(db.transactions).insert(_rows.first));
    final container = await _pump(tester, db: db);
    await tester.tap(find.bySemanticsLabel('This was me. Hide this note'));
    await tester.pumpAndSettle();
    expect(find.byType(UnusualCard), findsNothing);
    expect(container.read(unusualDismissedProvider), {'big'});
    expect(container.read(unusualNoteProvider('big')), isNull);
    final saved = await tester.runAsync(
      () => (db.select(db.transactions)..where((t) => t.id.equals('big'))).getSingle(),
    );
    expect(saved!.flagDismissed, isTrue, reason: 'the answer outlives this session');
  });

  testWidgets('an entry answered "This was me" earlier shows no card', (tester) async {
    await _pump(tester, rows: [_rows.first.copyWith(flagDismissed: true), ..._rows.skip(1)]);
    expect(find.byType(UnusualCard), findsNothing);
  });

  testWidgets('"Only unusual" finds the flagged entry and not the ordinary ones', (tester) async {
    final container = await _pump(tester);
    expect(container.read(unusualIdsProvider), {'big'});
  });

  testWidgets('"Only unusual" finds nothing while Smart help has it switched off', (tester) async {
    final container = await _pump(tester, settings: {'smart.pointOutUnusual': '0'});
    expect(container.read(unusualIdsProvider), isEmpty);
  });

  test('"This was me" leaves when the entry was last changed alone', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final row = _rows.first;
    await db.into(db.transactions).insert(row);
    await TransactionRepository(db).dismissUnusual(row.id);
    final saved = await (db.select(db.transactions)..where((t) => t.id.equals(row.id))).getSingle();
    expect(saved.flagDismissed, isTrue);
    expect(saved.updatedAt, row.updatedAt, reason: 'suggestions read it as the category choice');
  });

  testWidgets('switched off in Smart help, no card', (tester) async {
    await _pump(tester, settings: {'smart.pointOutUnusual': '0'});
    expect(find.byType(UnusualCard), findsNothing);
  });

  testWidgets('an ordinary lunch is not pointed out', (tester) async {
    final container = await _pump(tester);
    expect(container.read(unusualNoteProvider('l1')), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('unusual card golden, ${b.name}', (tester) async {
      await _pump(tester, brightness: b);
      await expectLater(
        find.byType(UnusualCard),
        matchesGoldenFile('goldens/unusual_card_${b.name}.png'),
      );
    });
  }
}
