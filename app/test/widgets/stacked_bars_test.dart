import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/widgets/charts/stacked_bars.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('two months with the same total stand the same height, whatever the parts', (
    tester,
  ) async {
    const parts = [
      StackPart(name: 'Sending', colour: Color(0xFF000001)),
      StackPart(name: 'Withdrawing', colour: Color(0xFF000002)),
      StackPart(name: 'Tax', colour: Color(0xFF000003)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const Scaffold(
          body: StackedBars(
            parts: parts,
            semanticLabel: 'Fees',
            columns: [
              StackColumn(values: [30000, 0, 0], figure: '30k', label: 'Sep'),
              StackColumn(values: [10000, 10000, 10000], figure: '30k', label: 'Oct'),
            ],
          ),
        ),
      ),
    );
    double height(String month, List<String> names) =>
        names.fold(0, (sum, n) => sum + tester.getSize(find.byKey(ValueKey('$month-$n'))).height);
    final sep = height('Sep', ['Sending']);
    // Oct's three parts plus the two gaps between them.
    final oct = height('Oct', ['Sending', 'Withdrawing', 'Tax']) + AkSpace.s0h * 2;
    expect(oct, closeTo(sep, 0.5));
  });
}
