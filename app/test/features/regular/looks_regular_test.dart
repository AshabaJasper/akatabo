import 'dart:convert';
import 'dart:io';

import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/regular/looks_regular_section.dart';
import 'package:akatabo/features/regular/regular_payments_screen.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:akatabo/features/transactions/transactions_providers.dart';
import 'package:akatabo/smart/regular/regular_detector.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

RegularParams _params() => RegularParams.fromJson(
  jsonDecode(File('assets/smart/regular_params.json').readAsStringSync()) as Map<String, Object?>,
);

/// DStv on the 3rd of five months, and lunch most days: only DStv is a bill.
final _rows = [
  for (final m in [6, 7, 8, 9, 10])
    txRow(
      id: 'dstv$m',
      amount: 45000,
      categoryId: DefaultIds.bills,
      description: 'DStv subscription',
      at: DateTime(2026, m, 3, 20),
    ),
  for (var d = 1; d <= 18; d++)
    txRow(id: 'lunch$d', amount: 5000, description: 'lunch', at: DateTime(2026, 11, d, 13)),
];

class _FakeRegular extends RegularPaymentRepository {
  _FakeRegular() : super(AppDatabase(NativeDatabase.memory()));

  final saved = <({String label, bool dismissed, int nextDueOn, int interval})>[];

  @override
  Future<String> addDetected({
    required String label,
    required String payeeKey,
    required int typicalAmount,
    required int amountLow,
    required int amountHigh,
    required int intervalDays,
    required int nextDueOn,
    required int timesSeen,
    String? categoryId,
    bool dismissed = false,
  }) async {
    saved.add((label: label, dismissed: dismissed, nextDueOn: nextDueOn, interval: intervalDays));
    return 'id';
  }
}

Future<_FakeRegular> _pump(
  WidgetTester tester, {
  Map<String, String> settings = const {},
  Brightness brightness = Brightness.light,
  List<RegularPayment> saved = const [],
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeRegular();
  final params = _params();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        appearanceProvider.overrideWithValue(const AkAppearance()),
        appNowProvider.overrideWithValue(_now),
        regularPaymentRepositoryProvider.overrideWithValue(repo),
        activeRegularProvider.overrideWith((ref) => Stream.value(const [])),
        allRegularProvider.overrideWith((ref) => Stream.value(saved)),
        allTransactionsProvider.overrideWith((ref) => Stream.value(_rows.reversed.toList())),
        regularParamsProvider.overrideWith((ref) async => params),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const RegularPaymentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

RegularPayment _savedDstv({
  required bool dismissed,
  String label = 'DStv subscription',
  String? categoryId = DefaultIds.bills,
  RegularSource source = RegularSource.detected,
}) {
  final at = DateTime(2026, 10, 3);
  return RegularPayment(
    id: 'r1',
    createdAt: at,
    updatedAt: at,
    label: label,
    categoryId: categoryId,
    payeeKey: label.toLowerCase(),
    typicalAmount: 45000,
    amountLow: 45000,
    amountHigh: 45000,
    intervalDays: 30,
    nextDueOn: 20261203,
    timesSeen: 5,
    source: source,
    remind: false,
    dismissed: dismissed,
  );
}

void main() {
  testWidgets('a monthly payment shows under Looks regular, lunch does not', (tester) async {
    await _pump(tester);
    expect(find.text('Looks regular'), findsOneWidget);
    expect(find.text('DStv subscription'), findsOneWidget);
    expect(find.text('lunch'), findsNothing);
    expect(find.textContaining('Paid 5 times, about every'), findsOneWidget);
    expect(find.text('None saved yet. Smart help found the ones below.'), findsOneWidget);
  });

  testWidgets('Add saves it with the predicted next date', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Add DStv subscription as a regular payment'));
    await tester.pumpAndSettle();
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.dismissed, isFalse);
    expect(repo.saved.single.label, 'DStv subscription');
    expect(repo.saved.single.nextDueOn, greaterThanOrEqualTo(20261119));
  });

  testWidgets('Dismiss stores it as dismissed', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Dismiss DStv subscription'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.dismissed, isTrue);
  });

  testWidgets('a second tap before the list updates does not save twice', (tester) async {
    final repo = await _pump(tester);
    final add = find.bySemanticsLabel('Add DStv subscription as a regular payment');
    await tester.tap(add);
    await tester.pump();
    expect(add, findsNothing, reason: 'hidden at once');
    expect(repo.saved, hasLength(1));
  });

  testWidgets('the same bill added by hand under another name is not offered', (tester) async {
    await _pump(
      tester,
      saved: [_savedDstv(dismissed: false, label: 'TV', source: RegularSource.manual)],
    );
    expect(find.byType(LooksRegularCard), findsNothing);
  });

  testWidgets('a payee already dismissed is not offered again', (tester) async {
    await _pump(tester, saved: [_savedDstv(dismissed: true)]);
    expect(find.byType(LooksRegularCard), findsNothing);
  });

  testWidgets('switched off in Smart help, no section', (tester) async {
    await _pump(tester, settings: {'smart.noticeRegular': '0'});
    expect(find.text('Looks regular'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('looks regular golden, ${b.name}', (tester) async {
      await _pump(tester, brightness: b);
      await expectLater(
        find.byType(LooksRegularSection),
        matchesGoldenFile('goldens/looks_regular_${b.name}.png'),
      );
    });
  }
}
