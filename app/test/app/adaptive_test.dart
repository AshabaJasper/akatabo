import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:akatabo/app/adaptive.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] in a window of [size] with optional display features (folds and hinges).
Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child, {
  List<DisplayFeature> features = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..displayFeatures = features;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: buildAkTheme(Brightness.light, const AkAppearance()), home: child),
  );
}

DisplayFeature _vertical(double left) => DisplayFeature(
  bounds: Rect.fromLTWH(left, 0, 40, 800),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

DisplayFeature _horizontal(double top) => DisplayFeature(
  bounds: Rect.fromLTWH(0, top, 1280, 40),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  testWidgets('a window is wide from 840dp: a phone stays single-column', (tester) async {
    final results = <double, bool>{};
    for (final width in [390.0, 839.0, 840.0]) {
      await _pump(
        tester,
        Size(width, 800),
        Builder(
          builder: (context) {
            results[width] = isWide(context);
            return const SizedBox();
          },
        ),
      );
    }
    expect(results, {390.0: false, 839.0: false, 840.0: true});
  });

  // The shell gives the content its place: beside the rail, at a fixed width. These mirror that.
  Widget panes() => const ContentFrame(
    left: 88,
    width: 1000,
    child: Row(
      children: [
        SizedBox(width: 88),
        SizedBox(
          width: 1000,
          child: WidePanes(
            primary: ColoredBox(key: ValueKey('primary'), color: Color(0xFF000000)),
            secondary: ColoredBox(key: ValueKey('secondary'), color: Color(0xFF000000)),
          ),
        ),
      ],
    ),
  );

  testWidgets('two panes split at a vertical fold, with nothing drawn across it', (tester) async {
    // The content runs from x=88 to x=1088; the fold sits at x=500 to 540.
    await _pump(tester, const Size(1280, 800), panes(), features: [_vertical(500)]);
    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(primary.left, 88);
    expect(primary.right, 500);
    expect(secondary.left, 540);
    expect(secondary.right, 1088);
  });

  testWidgets('without a fold the two panes share the width, 2 to 3', (tester) async {
    await _pump(tester, const Size(1280, 800), panes());
    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(primary.width / (primary.width + secondary.width), closeTo(2 / 5, 0.01));
  });

  testWidgets('a half-open horizontal fold keeps content off the hinge, from above it', (
    tester,
  ) async {
    // The hinge sits in the top half at y=300, so content uses the space below it.
    await _pump(
      tester,
      const Size(900, 800),
      const HingeSafe(child: SizedBox.expand()),
      features: [_horizontal(300)],
    );
    expect(tester.getRect(find.byType(SizedBox)).top, 340);
  });

  testWidgets('a half-open fold in the bottom half keeps content above it', (tester) async {
    await _pump(
      tester,
      const Size(900, 800),
      const HingeSafe(child: SizedBox.expand()),
      features: [_horizontal(600)],
    );
    expect(tester.getRect(find.byType(SizedBox)).bottom, 600);
  });

  testWidgets('a half-open fold reported with no height still keeps content off it', (
    tester,
  ) async {
    // Folding phones often report the crease as a line: no height at all.
    const fold = DisplayFeature(
      bounds: Rect.fromLTWH(0, 600, 900, 0),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
    await _pump(
      tester,
      const Size(900, 800),
      const HingeSafe(child: SizedBox.expand()),
      features: [fold],
    );
    expect(tester.getRect(find.byType(SizedBox)).bottom, 600);
  });

  testWidgets('a flat fold with no width is no hinge: the panes share the width', (tester) async {
    const fold = DisplayFeature(
      bounds: Rect.fromLTWH(500, 0, 0, 800),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );
    await _pump(tester, const Size(1280, 800), panes(), features: [fold]);
    final primary = tester.getRect(find.byKey(const ValueKey('primary')));
    final secondary = tester.getRect(find.byKey(const ValueKey('secondary')));
    expect(primary.width / (primary.width + secondary.width), closeTo(2 / 5, 0.01));
  });

  testWidgets('with no fold, HingeSafe leaves the content alone', (tester) async {
    await _pump(tester, const Size(900, 800), const HingeSafe(child: SizedBox.expand()));
    expect(tester.getRect(find.byType(SizedBox)).height, 800);
  });
}
