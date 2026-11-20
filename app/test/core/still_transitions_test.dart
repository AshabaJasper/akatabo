import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Opens a second screen, with the phone's "Remove animations" set as given, and stops
  /// one frame into the transition.
  Future<void> pushNext(WidgetTester tester, {required bool reduce}) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      disableAnimations: reduce,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const Scaffold(body: Text('first')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  Iterable<Widget> transitionsAround(WidgetTester tester, String text) => tester.widgetList(
    find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is FadeTransition || w is SlideTransition),
    ),
  );

  /// Whether a transition is still partway: fading in, or sliding from off its place.
  bool moving(Widget w) => switch (w) {
    FadeTransition(:final opacity) => opacity.value != 1,
    SlideTransition(:final position) => position.value != Offset.zero,
    _ => false,
  };

  testWidgets('with reduced motion the next screen is in place on the first frame', (tester) async {
    await pushNext(tester, reduce: true);
    expect(transitionsAround(tester, 'second').where(moving), isEmpty);
  });

  testWidgets('normally the next screen arrives through the platform transition', (tester) async {
    await pushNext(tester, reduce: false);
    expect(transitionsAround(tester, 'second').where(moving), isNotEmpty);
  });

  testWidgets('on iOS with reduced motion, swiping from the edge still goes back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pushNext(tester, reduce: true);
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsNothing);
      expect(find.text('first'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
