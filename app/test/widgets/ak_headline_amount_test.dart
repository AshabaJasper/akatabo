import 'package:akatabo/app/formats.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/widgets/ak_headline_amount.dart';
import 'package:akatabo/widgets/ak_hidden_amount.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Map<String, String> settings) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storedSettingsProvider.overrideWith((ref) => Stream.value(settings))],
      child: MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const Scaffold(body: AkHeadlineAmount(1284000, hideable: true, style: TextStyle())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('in full by default', (tester) async {
    await _pump(tester, const {});
    expect(find.text('UGX 1,284,000'), findsOneWidget);
  });

  testWidgets('short when chosen, and a screen reader still hears the full figure', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, {SettingKeys.amountStyle.name: AmountStyle.short.name});
    expect(find.text('UGX 1.28M'), findsOneWidget);
    expect(find.bySemanticsLabel('UGX 1,284,000'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Hide amounts still hides it, and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, {
      SettingKeys.amountStyle.name: AmountStyle.short.name,
      PrivacyKeys.hideAmounts.name: '1',
    });
    expect(find.text(hiddenFigure), findsOneWidget);
    expect(find.bySemanticsLabel('UGX 1,284,000'), findsNothing);
    expect(find.bySemanticsLabel(hiddenFigureLabel), findsOneWidget);
    semantics.dispose();
  });
}
