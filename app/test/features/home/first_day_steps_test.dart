// Home's first day lists three steps. Each one opens where it says, and the screen it opens
// names Home in its back link, since that is where the person came from.
import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../flutter_test_config.dart';
import '../../support/backup_seed.dart';
import '../../support/fake_security.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('"Check your categories" opens Categories, whose back link names Home', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = memoryDb();
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appNowProvider.overrideWithValue(testNow),
          ...securityOverrides(values: MapSecureValues()),
        ],
        child: AkataboApp(router: router, onboardingDone: true),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Check your categories'));
    await _settle(tester);
    expect(find.bySemanticsLabel('Back to Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Back to Settings'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back to Home'));
    await _settle(tester);
    expect(find.text('Check your categories'), findsOneWidget, reason: 'back on Home');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    addTearDown(db.close);
    semantics.dispose();
  });
}
