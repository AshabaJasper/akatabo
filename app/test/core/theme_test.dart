import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('main colour', () {
    for (final palette in akPalettes) {
      for (final b in Brightness.values) {
        test('${palette.id} replaces every palette token in ${b.name}', () {
          final base = b == Brightness.light ? akLightTokens : akDarkTokens;
          final applied = applyPalette(base, palette, b).byName;
          final expected = b == Brightness.light ? palette.light : palette.dark;
          for (final key in akPaletteKeys) {
            expect(applied[key], expected[key], reason: key);
          }
        });
      }
    }

    test('green is the drawn default and leaves the tokens unchanged', () {
      final green = paletteById('green');
      expect(applyPalette(akLightTokens, green, Brightness.light).byName, akLightTokens.byName);
      expect(applyPalette(akDarkTokens, green, Brightness.dark).byName, akDarkTokens.byName);
    });

    test('an unknown palette id falls back to green', () {
      expect(paletteById('nope').id, 'green');
    });
  });

  test('corners scale every radius and square removes them', () {
    expect(AkMetrics(AkCorners.rounded).lg, AkRadiusTokens.lg);
    expect(AkMetrics(AkCorners.slight).md, closeTo(4, 1e-9));
    final square = AkMetrics(AkCorners.square);
    expect([square.xs, square.sm, square.md, square.lg, square.pill], everyElement(0));
  });

  test('text size scales the type and keeps the line-height ratio', () {
    final standard = AkType.of(AkTextSize.standard, const Color(0xFF000000));
    final large = AkType.of(AkTextSize.large, const Color(0xFF000000));
    expect(standard.body.fontSize, 14);
    expect(large.body.fontSize, 16);
    expect(large.body.height, standard.body.height);
  });

  test('amounts use tabular figures and display text sets its optical size', () {
    final type = AkType.of(AkTextSize.standard, const Color(0xFF000000));
    expect(type.figure.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(type.figureXl.fontFamily, 'Bricolage Grotesque');
    expect(type.figureXl.fontVariations!.map((v) => v.axis), containsAll(<String>['wght', 'opsz']));
    expect(type.body.fontVariations!.map((v) => v.axis), isNot(contains('opsz')));
  });

  test('both themes build from tokens with every extension', () {
    for (final b in Brightness.values) {
      final theme = buildAkTheme(b, const AkAppearance());
      expect(theme.extension<AkColors>(), isNotNull);
      expect(theme.extension<AkType>(), isNotNull);
      expect(theme.extension<AkMetrics>(), isNotNull);
      expect(
        theme.scaffoldBackgroundColor,
        (b == Brightness.light ? akLightTokens : akDarkTokens).ground,
      );
    }
  });
}
