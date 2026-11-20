import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, double width, List<String> labels, String selected) async {
  tester.view
    ..physicalSize = const Size(390, 400)
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
    await _pump(tester, 340, const ['Light', 'Dark', 'Follow phone'], 'Light');
    expect(_width(tester, 'Light'), moreOrLessEquals(_width(tester, 'Follow phone'), epsilon: 1));
  });
}
