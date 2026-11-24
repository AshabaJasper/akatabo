// Found in the TalkBack pass on the emulator: the amount field on Add was announced only by
// its hint, "0", because the label sat on a separate node from the edit box. Each text
// field on Add must carry its own name on the node TalkBack focuses.
import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../flutter_test_config.dart';
import '../support/backup_seed.dart';
import '../support/fake_security.dart';

void main() {
  for (final (screen, route, name) in [
    ('Add', Routes.add, 'Amount in shillings'),
    ('All transactions', Routes.transactions, 'Search transactions'),
    ('Settings', Routes.settings, 'Search settings'),
  ]) {
    testWidgets('the first field on $screen is named on its own edit box', (tester) async {
      await _expectFieldNamed(tester, route, name);
    });
  }
}

Future<void> _expectFieldNamed(WidgetTester tester, String route, String name) async {
  final semantics = tester.ensureSemantics();
  final db = memoryDb();
  final router = buildRouter(initialLocation: route);
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
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }

  final field = tester.getSemantics(find.byType(EditableText).first);
  expect(field.flagsCollection.isTextField, isTrue);
  expect(field.label, contains(name));

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  addTearDown(db.close);
  semantics.dispose();
}
