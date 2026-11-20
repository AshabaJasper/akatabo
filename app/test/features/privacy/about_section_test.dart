import 'package:akatabo/app/font_licences.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/features/privacy/about_section.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      child: MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const SettingsPage(title: 'Privacy and data', children: [AboutSection()]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Akatabo',
      packageName: 'com.persmon.akatabo',
      version: '0.6.0',
      buildNumber: '6',
      buildSignature: '',
    ),
  );

  testWidgets('shows the version with its build number', (tester) async {
    await _pump(tester);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('0.6.0 (6)'), findsOneWidget);
  });

  testWidgets('leaves out the rows that need the owner\'s facts', (tester) async {
    await _pump(tester);
    expect(find.text('Privacy policy'), findsNothing);
    expect(find.text('Send feedback'), findsNothing);
  });

  testWidgets('Open-source licences opens the licence page for Akatabo', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('both bundled fonts are registered with their OFL text', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFontLicences();
    final entries = await LicenseRegistry.licenses.toList();
    for (final font in fontLicenceFiles.keys) {
      final entry = entries.where((e) => e.packages.contains(font)).toList();
      expect(entry, hasLength(1), reason: font);
      final text = entry.single.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('SIL OPEN FONT LICENSE'), reason: font);
    }
  });
}
