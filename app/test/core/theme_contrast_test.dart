import 'dart:math' as math;

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/contrast.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _text = 4.5;
const _mark = 3.0;

/// CIE 1976 L* (0 to 100) of an opaque colour, from its WCAG relative luminance.
double lightnessL(Color c) {
  final y = c.computeLuminance();
  final f = y > 216 / 24389 ? math.pow(y, 1 / 3).toDouble() : (24389 / 27 * y + 16) / 116;
  return 116 * f - 16;
}

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

  // Text on the page and inside the shared controls, in both themes. These are the colours
  // the widgets really use, so this is the contrast evidence; Flutter's pixel-sampling
  // textContrastGuideline misreads anti-aliased small text and is not used for it.
  for (final b in Brightness.values) {
    test('text in the shared controls reaches 4.5:1 in ${b.name}', () {
      final c = b == Brightness.light ? akLightTokens : akDarkTokens;
      final pairs = <String, (Color, Color)>{
        'ink on ground': (c.ink, c.ground),
        'ink on surface': (c.ink, c.surface),
        'ink-muted on ground (captions, eyebrows)': (c.inkMuted, c.ground),
        'ink-muted on surface (captions, nav labels)': (c.inkMuted, c.surface),
        'ink-muted on surface-sunk (segments not chosen, chips)': (c.inkMuted, c.surfaceSunk),
        'ink on surface-raised (chosen segment)': (c.ink, c.surfaceRaised),
        'money-out on ground and surface': (c.moneyOut, c.surface),
        'money-in on surface': (c.moneyIn, c.surface),
        'money-out on money-out-soft (Over chip, unusual card)': (c.moneyOut, c.moneyOutSoft),
        'money-in on money-in-soft': (c.moneyIn, c.moneyInSoft),
        'brand-text on surface-sunk': (c.brandText, c.surfaceSunk),
        'on-light-fill on accent': (c.onLightFill, c.accent),
        'on-light-fill on acct-mtn (chosen chip)': (c.onLightFill, c.acctMtn),
        'on-light-fill on acct-cash (chosen chip)': (c.onLightFill, c.acctCash),
        'on-brand on acct-airtel (chosen chip)': (c.onBrand, c.acctAirtel),
        'on-brand on acct-bank (chosen chip)': (c.onBrand, c.acctBank),
        'on-heat-4 on heat-4 (calendar)': (c.onHeat4, c.heat4),
      };
      final failing = [
        for (final e in pairs.entries)
          if (contrastRatio(e.value.$1, e.value.$2) < _text)
            '${e.key}: ${contrastRatio(e.value.$1, e.value.$2).toStringAsFixed(2)}',
      ];
      expect(failing, isEmpty);
    });
  }

  // Money colours > Red and green (the default): the red and green take the place of
  // money-out and money-in everywhere, so they meet the same text pairs. They also differ in
  // lightness by 20 or more L*, so the pair still reads apart without hue.
  for (final b in Brightness.values) {
    test('red and green money colours reach 4.5:1 and differ by 20 L* in ${b.name}', () {
      final base = b == Brightness.light ? akLightTokens : akDarkTokens;
      final c = applyMoneyColours(base, AkMoneyColours.redGreen);
      final pairs = <String, (Color, Color)>{
        'money-out-red on ground': (c.moneyOut, c.ground),
        'money-out-red on surface': (c.moneyOut, c.surface),
        'money-in-green on ground': (c.moneyIn, c.ground),
        'money-in-green on surface': (c.moneyIn, c.surface),
        'money-out-red on its soft partner (Over chip)': (c.moneyOut, c.moneyOutSoft),
        'money-in-green on its soft partner': (c.moneyIn, c.moneyInSoft),
        'ink on money-out-red-soft': (c.ink, c.moneyOutSoft),
        'ink on money-in-green-soft': (c.ink, c.moneyInSoft),
      };
      final failing = [
        for (final e in pairs.entries)
          if (contrastRatio(e.value.$1, e.value.$2) < _text)
            '${e.key}: ${contrastRatio(e.value.$1, e.value.$2).toStringAsFixed(2)}',
      ];
      expect(failing, isEmpty);
      expect((lightnessL(c.moneyOut) - lightnessL(c.moneyIn)).abs(), greaterThanOrEqualTo(20));
    });
  }

  test('CIE L* matches reference values', () {
    expect(lightnessL(const Color(0xFFFFFFFF)), closeTo(100, 1e-6));
    expect(lightnessL(const Color(0xFF000000)), closeTo(0, 1e-6));
    // Mid grey #777777 is L* 50.0.
    expect(lightnessL(const Color(0xFF777777)), closeTo(50, 0.1));
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
          'money-in-on-brand on brand-raised (Money in tile)': (
            c.moneyInOnBrand,
            c.brandRaised,
            _text,
          ),
          'money-in-green-on-brand on brand-raised (Money in tile)': (
            c.moneyInGreenOnBrand,
            c.brandRaised,
            _text,
          ),
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
