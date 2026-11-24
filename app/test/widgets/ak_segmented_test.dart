import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, double width, List<String> labels, String selected) async {
  tester.view
    ..physicalSize = const Size(480, 400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAkTheme(Brightness.light, const AkAppearance()),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: AkSegmented<String>(
              segments: [for (final l in labels) AkSegment(l, l)],
              selected: selected,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

bool _oneLine(WidgetTester tester, String label) {
  final p = tester.renderObject<RenderParagraph>(find.text(label));
  final size = p.text.style?.fontSize ?? 14;
  return p.size.height < size * 2;
}

double _width(WidgetTester tester, String label) =>
    tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(InkWell))).width;

void main() {
  const period = ['This month', 'This year', 'All', 'Custom'];

  testWidgets('a long label takes room from a short one instead of breaking', (tester) async {
    // The Export period control at its drawn width: equal quarters are too narrow for
    // "This month" while "All" has room to spare.
    await _pump(tester, 304, period, 'This month');
    for (final l in period) {
      expect(_oneLine(tester, l), isTrue, reason: '$l must not break while room is left');
    }
    expect(_width(tester, 'This month'), greaterThan(_width(tester, 'All')));
  });

  testWidgets('labels that fit keep the drawn even split', (tester) async {
    // Wide enough for "Follow phone" at the 24 Nov 2026 type (body-md 16) in a third.
    await _pump(tester, 420, const ['Light', 'Dark', 'Follow phone'], 'Light');
    expect(_width(tester, 'Light'), moreOrLessEquals(_width(tester, 'Follow phone'), epsilon: 1));
  });

  testWidgets('labels a little too wide shrink together instead of breaking', (tester) async {
    // Add's kind row on a 390 phone: the three labels at body 16 are a few pixels too wide.
    const kinds = ['Money out', 'Money in', 'Move money'];
    await _pump(tester, 272, kinds, 'Money out');
    for (final l in kinds) {
      expect(_oneLine(tester, l), isTrue, reason: '$l must not break');
      final size = tester.renderObject<RenderParagraph>(find.text(l)).text.style!.fontSize!;
      expect(size, greaterThanOrEqualTo(AkTextTokens.body.size * 14 / 16 - 1e-9));
      expect(size, lessThan(AkTextTokens.body.size));
    }
  });

  testWidgets('labels never shrink below the floor; past it they keep the even split', (
    tester,
  ) async {
    const kinds = ['Money out', 'Money in', 'Move money'];
    await _pump(tester, 180, kinds, 'Money out');
    final size = tester
        .renderObject<RenderParagraph>(find.text('Move money'))
        .text
        .style!
        .fontSize!;
    expect(size, AkTextTokens.body.size);
    expect(_width(tester, 'Money out'), moreOrLessEquals(_width(tester, 'Move money'), epsilon: 1));
  });

  testWidgets('every width in the shrink range keeps the labels on one line', (tester) async {
    // Floating-point rounding once threw away a scale that fitted exactly, so the labels
    // wrapped on some widths.
    const kinds = ['Money out', 'Money in', 'Move money'];
    // From where the floor is reached (about 259) to where they fit at full size (about 290).
    for (var w = 259.0; w <= 300; w += 0.25) {
      await _pump(tester, w, kinds, 'Money out');
      await tester.pumpAndSettle(); // the label size eases over with AkMotion
      for (final l in kinds) {
        expect(_oneLine(tester, l), isTrue, reason: '$l at $w');
      }
    }
  });
}
