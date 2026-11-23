import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:akatabo/widgets/ak_category_choices.dart';
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

  group('category colours', () {
    test('Colourful leaves every token as it is', () {
      expect(applyCategoryColours(akLightTokens, AkCategoryColours.colourful), akLightTokens);
    });

    test('One colour draws every category in the main colour; accounts keep theirs', () {
      final c = applyCategoryColours(akDarkTokens, AkCategoryColours.oneColour);
      for (final v in [c.catGreen, c.catAmber, c.catRed, c.catSlate, c.catOlive]) {
        expect(v, akDarkTokens.brand);
      }
      expect(c.acctAirtel, akDarkTokens.acctAirtel);
    });

    test('Greys draws every category in slate', () {
      final c = applyCategoryColours(akLightTokens, AkCategoryColours.greys);
      expect(c.catPink, akLightTokens.catSlate);
      expect(c.catTeal, akLightTokens.catSlate);
    });

    testWidgets('account colours keep their own colour under Greys', (tester) async {
      // Seen on the Pixel: under Greys the purple and teal account discs were the same slate.
      late Color purple, teal, cash;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAkTheme(
            Brightness.dark,
            const AkAppearance(categoryColours: AkCategoryColours.greys),
          ),
          home: Builder(
            builder: (context) {
              purple = accountColour(context, 'cat-purple');
              teal = accountColour(context, 'cat-teal');
              cash = accountColour(context, 'acct-cash');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(purple, akDarkTokens.catPurple);
      expect(teal, akDarkTokens.catTeal);
      expect(cash, akDarkTokens.acctCash);
    });

    test('an amber category takes the light icon once it is drawn in another colour', () {
      expect(categoryIconColour(akLightTokens, 'cat-amber'), akLightTokens.onLightFill);
      expect(categoryIconColour(akLightTokens, 'cat-blue'), akLightTokens.onBrand);
      for (final mode in [AkCategoryColours.oneColour, AkCategoryColours.greys]) {
        final c = applyCategoryColours(akLightTokens, mode);
        expect(categoryIconColour(c, 'cat-amber'), c.onBrand, reason: mode.name);
        expect(categoryIconColour(c, 'cat-olive'), c.onBrand, reason: mode.name);
      }
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
