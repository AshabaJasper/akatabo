import 'package:akatabo/core/brand/akatabo_mark.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:akatabo/widgets/ak_logo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light, double scale = 1}) =>
    MaterialApp(
      theme: buildAkTheme(brightness, const AkAppearance()),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

CustomPaint _mark(WidgetTester tester) => tester.widget<CustomPaint>(
  find.descendant(
    of: find.byType(AkLogo),
    matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AkMarkPainter),
  ),
);

void main() {
  const style = TextStyle(fontSize: 20);

  testWidgets('screen readers hear the name once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const AkLogo(style: style)));
    expect(find.bySemanticsLabel('Akatabo'), findsOneWidget);
    expect(find.text('Akatabo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the mark grows with the text style and the phone text size', (tester) async {
    await tester.pumpWidget(_host(const AkLogo(style: style)));
    expect(_mark(tester).size, const Size.square(20 * AkLogo.markToFontSize));
    await tester.pumpWidget(_host(const AkLogo(style: style), scale: 1.5));
    expect(_mark(tester).size, const Size.square(30 * AkLogo.markToFontSize));
  });

  testWidgets('mark alone has no wordmark', (tester) async {
    await tester.pumpWidget(_host(const AkLogo(style: style, wordmark: false)));
    expect(find.text('Akatabo'), findsNothing);
    expect(_mark(tester), isNotNull);
  });

  testWidgets('on the ground, the cover turns paper in dark mode', (tester) async {
    late AkMarkColours light, dark;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            light = AkLogo.coloursFor(context, AkLogoOn.ground);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            dark = AkLogo.coloursFor(context, AkLogoOn.ground);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    // MaterialApp animates a theme change; brightness flips halfway, so let it settle.
    await tester.pumpAndSettle();
    expect((light as AkMarkInColour).cover, akLightTokens.brandDeep);
    expect((dark as AkMarkInColour).cover, akLightTokens.ground);
  });

  testWidgets('a long name at a large text size does not overflow a narrow box', (tester) async {
    await tester.pumpWidget(
      _host(const SizedBox(width: 120, child: AkLogo(style: style)), scale: 2),
    );
    expect(tester.takeException(), isNull);
  });
}
