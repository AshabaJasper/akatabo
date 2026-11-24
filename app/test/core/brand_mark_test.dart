import 'package:akatabo/core/brand/akatabo_mark.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the mark is centred on its grid', () {
    final c = AkMarkGeometry.bounds.center;
    expect(c.dx, closeTo(AkMarkGeometry.grid / 2, 1));
    expect(c.dy, closeTo(AkMarkGeometry.grid / 2, 1));
  });

  test('the rising line, caps included, stays inside the cover', () {
    final inner = AkMarkGeometry.cover.outerRect.deflate(AkMarkGeometry.lineWidth / 2);
    for (final p in AkMarkGeometry.line) {
      expect(inner.contains(p), isTrue, reason: '$p');
    }
  });

  test('the one-colour gap keeps the cover apart from the page block', () {
    final gapped = AkMarkGeometry.cover.inflate(AkMarkGeometry.monoGap);
    // The page block shows beyond the gap on the right and at the bottom.
    expect(AkMarkGeometry.backPage.right, greaterThan(gapped.right));
    expect(AkMarkGeometry.backPage.bottom, greaterThan(gapped.bottom));
  });

  testWidgets('paints in colour and in one colour at notification size', (tester) async {
    for (final colours in [
      AkMarkInColour(
        cover: akLightTokens.brandDeep,
        page: akDarkTokens.brandBright,
        line: akLightTokens.accent,
      ),
      AkMarkInOneColour(akLightTokens.brandDeep),
    ]) {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(size: const Size.square(24), painter: AkMarkPainter(colours)),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('equal colours do not repaint; a new share does', () {
    AkMarkInColour make() => AkMarkInColour(
      cover: akLightTokens.brandDeep,
      page: akDarkTokens.brandBright,
      line: akLightTokens.accent,
    );
    expect(AkMarkPainter(make()).shouldRepaint(AkMarkPainter(make())), isFalse);
    expect(
      AkMarkPainter(AkMarkInOneColour(akLightTokens.ink))
          .shouldRepaint(AkMarkPainter(AkMarkInOneColour(akLightTokens.ink))),
      isFalse,
    );
    expect(AkMarkPainter(make(), share: 0.5).shouldRepaint(AkMarkPainter(make())), isTrue);
  });
}
