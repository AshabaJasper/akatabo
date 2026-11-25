import 'package:akatabo/app/adaptive.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/app/shell_scaffold.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The left inset each tab sees, by tab index.
final _leftInset = <int, double>{};

GoRouter _router() => GoRouter(
  initialLocation: '/t0',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        for (var i = 0; i < 4; i++)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/t$i',
                builder: (_, _) => Builder(
                  builder: (context) {
                    _leftInset[i] = MediaQuery.paddingOf(context).left;
                    return Align(alignment: Alignment.topLeft, child: Text('tab $i'));
                  },
                ),
              ),
            ],
          ),
      ],
    ),
    GoRoute(path: Routes.add, builder: (_, _) => const Text('add')),
  ],
);

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildAkTheme(Brightness.light, const AkAppearance()),
      routerConfig: _router(),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _labelColour(WidgetTester tester, String label) => tester
    .widget<RichText>(find.descendant(of: find.text(label), matching: find.byType(RichText)))
    .text
    .style
    ?.color;

void main() {
  testWidgets('a wide window has the rail, not the bottom bar, and marks the open tab', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(AkBottomNav), findsNothing);
    final c = tester.element(find.byType(ShellScaffold)).colors;
    expect(_labelColour(tester, 'Home'), c.brandText);
    expect(_labelColour(tester, 'Insights'), c.inkMuted);
  });

  testWidgets('a short landscape window at a large text size can still reach Settings', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpShell(tester, const Size(840, 300));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('tab 3'), findsOneWidget);
  });

  testWidgets('a left cutout widens the rail once, and the content is placed after it', (
    tester,
  ) async {
    await _pumpShell(tester, const Size(1280, 800), padding: const FakeViewPadding(left: 30));
    // 1280 less the 88 rail and the 30 cutout leaves 1162; the 1120 content is centred in it.
    expect(tester.widget<ContentFrame>(find.byType(ContentFrame)).left, 88 + 30 + 21);
    expect(_leftInset[0], 0);
  });

  testWidgets('on a wide window the content starts below the status bar', (tester) async {
    await _pumpShell(tester, const Size(1280, 800), padding: const FakeViewPadding(top: 24));
    expect(tester.getTopLeft(find.text('tab 0')).dy, greaterThanOrEqualTo(24));
  });

  testWidgets('a phone keeps the bottom bar', (tester) async {
    await _pumpShell(tester, const Size(390, 844));
    expect(find.byType(AkBottomNav), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
