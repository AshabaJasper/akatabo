import 'dart:convert';
import 'dart:io';

import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/providers.dart';
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
        allTransactionsProvider.overrideWith((ref) => Stream.value(_rows)),
        transactionByIdProvider('big').overrideWith((ref) => Stream.value(_rows.first)),
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

  testWidgets('"This was me" hides the card for the rest of the session', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('This was me. Hide this note'));
    await tester.pumpAndSettle();
    expect(find.byType(UnusualCard), findsNothing);
    expect(container.read(unusualDismissedProvider), {'big'});
    // Still hidden when the note is worked out again in the same session.
    expect(container.read(unusualNoteProvider('big')), isNull);
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
