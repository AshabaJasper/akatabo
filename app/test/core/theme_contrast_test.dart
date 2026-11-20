import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/contrast.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _text = 4.5;
const _mark = 3.0;

void main() {
  test('the contrast function matches the WCAG reference values', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 1e-9));
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)), closeTo(1, 1e-9));
    // #767676 on white is the well-known 4.54:1 grey.
    expect(contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)), closeTo(4.54, 0.01));
    // The order of the two colours does not matter.
    expect(
      contrastRatio(const Color(0xFF0F3D30), const Color(0xFFFFFFFF)),
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF0F3D30)),
    );
  });

  // Every main colour, in both themes: text drawn on the brand fills and brand text on the
  // page must stay readable, and the switch and selection marks must stand out.
  for (final palette in akPalettes) {
    for (final b in Brightness.values) {
      test('${palette.label} keeps its contrast in ${b.name}', () {
        final base = b == Brightness.light ? akLightTokens : akDarkTokens;
        final c = applyPalette(base, palette, b);
        final pairs = <String, (Color, Color, double)>{
          'on-brand text on brand (buttons)': (c.onBrand, c.brand, _text),
          'on-brand text on brand-raised (Home tiles)': (c.onBrand, c.brandRaised, _text),
          'on-brand text on brand-deep (Home header)': (c.onBrand, c.brandDeep, _text),
          'on-brand-muted text on brand-deep (Home header)': (c.onBrandMuted, c.brandDeep, _text),
          'accent text on brand-deep (Home comparison)': (c.accent, c.brandDeep, _text),
          'on-brand-muted text on brand-raised': (c.onBrandMuted, c.brandRaised, _text),
          'brand-text links on ground': (c.brandText, c.ground, _text),
          'brand-text links on surface': (c.brandText, c.surface, _text),
          'on-deep text on screen-deep (Welcome)': (c.onDeep, c.screenDeep, _text),
          'on-brand-muted text on screen-deep': (c.onBrandMuted, c.screenDeep, _text),
          'switch-on track against surface': (c.switchOn, c.surface, _mark),
          'switch thumb on switch-on': (c.onBrand, c.switchOn, _mark),
          'brand-bright focus ring against surface': (c.brandBright, c.surface, _mark),
          // Some main colours sit close to the dark card (Charcoal 1.76:1), so each swatch
          // has a 1px ink-muted edge that always stands out.
          'Main colour swatch edge against surface': (c.inkMuted, c.surface, _mark),
        };
        final failing = [
          for (final e in pairs.entries)
            if (contrastRatio(e.value.$1, e.value.$2) < e.value.$3)
              '${e.key}: ${contrastRatio(e.value.$1, e.value.$2).toStringAsFixed(2)}',
        ];
        expect(failing, isEmpty);
      });
    }
  }
}
