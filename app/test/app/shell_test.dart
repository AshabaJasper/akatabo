import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpApp(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [appearanceProvider.overrideWithValue(AkAppearance(themeMode: mode))],
      child: const AkataboApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on Home with five navigation targets', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Home'), findsWidgets);
    for (final label in ['Home', 'Insights', 'Add a transaction', 'Budgets', 'Settings']) {
      expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
    }
  });

  testWidgets('each tab opens its screen', (tester) async {
    await _pumpApp(tester);
    for (final tab in ['Insights', 'Budgets', 'Settings', 'Home']) {
      await tester.tap(find.bySemanticsLabel(tab).last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Scaffold, tab), findsWidgets, reason: tab);
    }
  });

  testWidgets('Add covers the tabs and closing it returns to where the person was', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Insights').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add a transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsNothing);
    expect(find.widgetWithText(Scaffold, 'Insights'), findsWidgets);
  });

  testWidgets('every navigation target is at least 44px', (tester) async {
    await _pumpApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('shell golden, ${mode.name}', (tester) async {
      await _pumpApp(tester, mode: mode);
      await expectLater(
        find.byType(AkataboApp),
        matchesGoldenFile('goldens/shell_${mode.name}.png'),
      );
    });
  }
}
