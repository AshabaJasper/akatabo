import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/features/privacy/about_section.dart';
import 'package:akatabo/features/settings/about_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The stock licence page and the clipboard are plugins' work; the test phone answers them.
Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  Future<String> Function()? version,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appVersionProvider.overrideWith((ref) => (version ?? () async => '0.2.0 (2)')())],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AboutScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Records what the app puts on the clipboard, or fails like a phone that will not let it.
String? _copied;
void _phoneClipboard(WidgetTester tester, {bool fails = false}) {
  _copied = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
    call,
  ) async {
    if (call.method == 'Clipboard.setData') {
      if (fails) throw PlatformException(code: 'unavailable');
      _copied = (call.arguments as Map)['text'] as String?;
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('names the app, the version, the licence and where the code is', (tester) async {
    await _pump(tester);
    expect(find.text('About Akatabo'), findsOneWidget);
    expect(find.text('0.2.0 (2)'), findsOneWidget, reason: 'the version of this copy');
    expect(find.text('GPL-3.0'), findsOneWidget);
    expect(find.textContaining('github.com/AshabaJasper/akatabo'), findsOneWidget);
    expect(find.textContaining('cannot reach the internet'), findsOneWidget);
    expect(find.textContaining('Luganda for "little book"'), findsOneWidget);
  });

  testWidgets('a version that cannot be read says so instead of leaving the row empty', (
    tester,
  ) async {
    await _pump(tester, version: () async => throw StateError('no package info'));
    expect(find.text('Not known'), findsOneWidget);
  });

  testWidgets('Copy project link puts the whole link on the clipboard and says so', (tester) async {
    _phoneClipboard(tester);
    await _pump(tester);
    tester.takeAnnouncements();
    expect(find.text(linkCopiedMessage), findsNothing, reason: 'nothing said before it is asked');

    await tester.tap(find.text('Copy project link'));
    await tester.pumpAndSettle();
    expect(_copied, 'https://github.com/AshabaJasper/akatabo');
    expect(find.text(linkCopiedMessage), findsOneWidget);
    expect(tester.takeAnnouncements().map((a) => a.message), [linkCopiedMessage]);
  });

  testWidgets('a phone that refuses the clipboard is told so, and the page stays', (tester) async {
    _phoneClipboard(tester, fails: true);
    await _pump(tester);
    await tester.tap(find.text('Copy project link'));
    await tester.pumpAndSettle();
    expect(find.text('The link could not be copied.'), findsOneWidget);
    expect(find.text(linkCopiedMessage), findsNothing);
    expect(find.text('About Akatabo'), findsOneWidget);
  });

  testWidgets('Open-source licences opens the licence page', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('fits the smallest phone at the largest text size', (tester) async {
    await _pump(tester, size: const Size(360, 640), textScale: 2);
    expect(tester.takeException(), isNull, reason: 'no overflow');
    // The whole page is still reachable by scrolling.
    await tester.scrollUntilVisible(
      find.textContaining('Luganda'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Luganda'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('about golden, ${b.name}', (tester) async {
      await _pump(tester, brightness: b);
      await expectLater(find.byType(AboutScreen), matchesGoldenFile('goldens/about_${b.name}.png'));
    });
  }
}
