import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/features/transactions/transaction_row.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/widgets/ak_hidden_amount.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

Future<void> _pump(WidgetTester tester, {required bool hide}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith(
          (ref) => Stream.value({PrivacyKeys.hideAmounts.name: hide ? '1' : '0'}),
        ),
      ],
      child: MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: Scaffold(
          body: Column(
            children: [
              const AkHiddenAmount('UGX 900,000', style: TextStyle()),
              TransactionRow(
                transaction: txRow(amount: 45000, description: 'Lunch'),
                now: DateTime(2026, 11, 19, 12),
                accountName: 'MTN MoMo',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('rows show dots and say "amount hidden" until a main figure is tapped', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, hide: true);
    expect(find.text('- 45,000'), findsNothing);
    expect(find.text(hiddenFigure), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('Lunch, amount hidden')), findsOneWidget);

    await tester.tap(find.text(hiddenFigure).first);
    await tester.pump();
    expect(find.text('- 45,000'), findsOneWidget);
    expect(find.text('UGX 900,000'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with Hide amounts off, rows show the amount', (tester) async {
    await _pump(tester, hide: false);
    expect(find.text('- 45,000'), findsOneWidget);
  });
}
