import 'package:material_ui/material_ui.dart';

import 'ak_appearance.dart';
import 'still_transitions.dart';
import 'token_colour.dart';
import 'tokens.g.dart';

export 'ak_appearance.dart';
export 'tokens.g.dart' show AkSize, AkSpace, AkColorTokens;

/// Replaces the brand tokens with the chosen main colour. Every key in [akPaletteKeys]
/// must be handled here; a test checks that.
AkColorTokens applyPalette(AkColorTokens base, AkPalette palette, Brightness brightness) {
  final m = brightness == Brightness.light ? palette.light : palette.dark;
  return base.copyWith(
    brand: m['brand'],
    brandRaised: m['brand-raised'],
    brandSoft: m['brand-soft'],
    onBrandMuted: m['on-brand-muted'],
    brandDeep: m['brand-deep'],
    brandBright: m['brand-bright'],
    brandText: m['brand-text'],
    switchOn: m['switch-on'],
    screenDeep: m['screen-deep'],
    heat1: m['heat-1'],
    heat2: m['heat-2'],
    heat3: m['heat-3'],
    heat4: m['heat-4'],
  );
}

/// "Category colours": under One colour every `cat-` token becomes the main colour, under
/// Greys every one becomes `cat-slate`. Account colours are not category colours and stay.
/// The `-past` tints are not used on any screen, so they are left as they are.
AkColorTokens applyCategoryColours(AkColorTokens c, AkCategoryColours mode) {
  final Color one;
  switch (mode) {
    case AkCategoryColours.colourful:
      return c;
    case AkCategoryColours.oneColour:
      one = c.brand;
    case AkCategoryColours.greys:
      one = c.catSlate;
  }
  return c.copyWith(
    catGreen: one,
    catBlue: one,
    catAmber: one,
    catPurple: one,
    catPink: one,
    catSlate: one,
    catOrange: one,
    catTeal: one,
    catIndigo: one,
    catBrown: one,
    catOlive: one,
    catRed: one,
  );
}

/// The `cat-` colours as drawn, before "Category colours" changes them. They are the same in
/// every main colour, so the base tokens of the brightness are enough. For the colour picker
/// and for charts whose parts are not categories (the Fees parts), which must stay apart.
AkColorTokens drawnCategoryColours(Brightness brightness) =>
    brightness == Brightness.dark ? akDarkTokens : akLightTokens;

/// An account's colour. Two account colours borrow `cat-` tokens (purple and teal), and
/// "Category colours" is about categories: under Greys they would both turn slate, so accounts
/// read the drawn `cat-` colours instead.
Color accountColour(BuildContext context, String token) => colourForToken(
  token.startsWith('cat-') ? drawnCategoryColours(Theme.of(context).brightness) : context.colors,
  token,
);

AkPalette paletteById(String id) =>
    akPalettes.firstWhere((p) => p.id == id, orElse: () => akPalettes.first);

/// The colour tokens for one theme, after the main colour is applied.
class AkColors extends ThemeExtension<AkColors> {
  const AkColors(this.tokens);
  final AkColorTokens tokens;

  @override
  AkColors copyWith({AkColorTokens? tokens}) => AkColors(tokens ?? this.tokens);

  @override
  AkColors lerp(AkColors? other, double t) =>
      other == null ? this : AkColors(AkColorTokens.lerp(tokens, other.tokens, t));
}

/// Every text style token as a ready [TextStyle] in `ink`, scaled by the Text size setting.
class AkType extends ThemeExtension<AkType> {
  AkType._(this.factor, Color ink)
    : displayXl = _style(AkTextTokens.displayXl, factor, ink),
      figureXl = _style(AkTextTokens.figureXl, factor, ink, figures: true),
      figureLg = _style(AkTextTokens.figureLg, factor, ink, figures: true),
      displayLg = _style(AkTextTokens.displayLg, factor, ink),
      titleLg = _style(AkTextTokens.titleLg, factor, ink),
      displaySm = _style(AkTextTokens.displaySm, factor, ink),
      headline = _style(AkTextTokens.headline, factor, ink),
      headlineSm = _style(AkTextTokens.headlineSm, factor, ink),
      title = _style(AkTextTokens.title, factor, ink),
      keypad = _style(AkTextTokens.keypad, factor, ink, figures: true),
      bodyLg = _style(AkTextTokens.bodyLg, factor, ink),
      button = _style(AkTextTokens.button, factor, ink),
      bodyMd = _style(AkTextTokens.bodyMd, factor, ink),
      body = _style(AkTextTokens.body, factor, ink),
      bodyStrong = _style(AkTextTokens.bodyStrong, factor, ink),
      figure = _style(AkTextTokens.figure, factor, ink, figures: true),
      bodySm = _style(AkTextTokens.bodySm, factor, ink),
      caption = _style(AkTextTokens.caption, factor, ink),
      captionStrong = _style(AkTextTokens.captionStrong, factor, ink),
      chartLabel = _style(AkTextTokens.chartLabel, factor, ink, figures: true),
      eyebrow = _style(
        AkTextTokens.caption,
        factor,
        ink,
      ).copyWith(letterSpacing: AkTextTokens.caption.size * factor * 0.06);

  factory AkType.of(AkTextSize size, Color ink) => AkType._(size.factor, ink);

  final double factor;
  final TextStyle displayXl;
  final TextStyle figureXl;
  final TextStyle figureLg;
  final TextStyle displayLg;
  final TextStyle titleLg;
  final TextStyle displaySm;
  final TextStyle headline;
  final TextStyle headlineSm;
  final TextStyle title;
  final TextStyle keypad;
  final TextStyle bodyLg;
  final TextStyle button;
  final TextStyle bodyMd;
  final TextStyle body;
  final TextStyle bodyStrong;

  /// Amounts in rows and tables: tabular figures so columns line up.
  final TextStyle figure;
  final TextStyle bodySm;
  final TextStyle caption;
  final TextStyle captionStrong;
  final TextStyle chartLabel;

  /// Section headings and field labels: `caption`, uppercase, 0.06em tracking.
  /// Callers upper-case the text; the style only sets the tracking.
  final TextStyle eyebrow;

  static TextStyle _style(AkTextToken t, double factor, Color ink, {bool figures = false}) {
    final size = t.size * factor;
    final display = t.family == AkTextTokens.display;
    return TextStyle(
      inherit: false,
      fontFamily: t.family,
      fontSize: size,
      height: t.lineHeight / t.size,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: t.weight,
      color: ink,
      textBaseline: TextBaseline.alphabetic,
      // The browser sets the optical size axis from the font size; Flutter does not.
      fontVariations: [
        FontVariation.weight(t.weight.value.toDouble()),
        if (display) FontVariation('opsz', size.clamp(12, 96)),
      ],
      fontFeatures: [if (figures) const FontFeature.tabularFigures()],
    );
  }

  @override
  AkType copyWith() => this;

  @override
  AkType lerp(AkType? other, double t) => t < 0.5 || other == null ? this : other;
}

/// Corner radii after the Corners setting.
class AkMetrics extends ThemeExtension<AkMetrics> {
  AkMetrics(this.corners)
    : xs = AkRadiusTokens.xs * corners.factor,
      sm = AkRadiusTokens.sm * corners.factor,
      md = AkRadiusTokens.md * corners.factor,
      lg = AkRadiusTokens.lg * corners.factor,
      pill = AkRadiusTokens.pill * corners.factor;

  final AkCorners corners;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double pill;

  @override
  AkMetrics copyWith({AkCorners? corners}) => AkMetrics(corners ?? this.corners);

  @override
  AkMetrics lerp(AkMetrics? other, double t) => t < 0.5 || other == null ? this : other;
}

/// Builds the light or dark theme from tokens plus the Appearance settings.
ThemeData buildAkTheme(Brightness brightness, AkAppearance appearance) {
  final base = brightness == Brightness.light ? akLightTokens : akDarkTokens;
  final c = applyCategoryColours(
    applyPalette(base, paletteById(appearance.paletteId), brightness),
    appearance.categoryColours,
  );
  final type = AkType.of(appearance.textSize, c.ink);
  final metrics = AkMetrics(appearance.corners);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    secondary: c.accent,
    onSecondary: c.ink,
    error: c.moneyOut,
    onError: c.onBrand,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceSunk,
    surfaceContainerHigh: c.surfaceSunk,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainerLowest: c.surface,
    outline: c.lineStrong,
    outlineVariant: c.line,
    shadow: c.ink.withValues(alpha: 0),
    scrim: c.ink.withValues(alpha: 0.5),
  );

  final textTheme = TextTheme(
    displayLarge: type.displayXl,
    displayMedium: type.displayLg,
    displaySmall: type.displaySm,
    headlineMedium: type.headline,
    headlineSmall: type.headlineSm,
    titleLarge: type.titleLg,
    titleMedium: type.title,
    titleSmall: type.bodyStrong,
    bodyLarge: type.bodyLg,
    bodyMedium: type.body,
    bodySmall: type.bodySm,
    labelLarge: type.button,
    labelMedium: type.captionStrong,
    labelSmall: type.caption,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    fontFamily: AkTextTokens.sans,
    textTheme: textTheme,
    dividerColor: c.line,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: StillWhenReduced(),
        TargetPlatform.iOS: StillWhenReduced(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
    highlightColor: c.ink.withValues(alpha: 0.04),
    splashColor: c.ink.withValues(alpha: 0.08),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.brand,
      selectionColor: c.brandSoft,
      selectionHandleColor: c.brand,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.lg),
        side: BorderSide(color: c.line),
      ),
      titleTextStyle: type.title,
      contentTextStyle: type.body.copyWith(color: c.inkMuted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: c.surface,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: c.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(metrics.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: type.body.copyWith(color: c.ground),
      actionTextColor: c.ground,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(metrics.md)),
    ),
    extensions: [AkColors(c), type, metrics],
  );
}

/// Short access from a widget: `context.colors.brand`, `context.type.figure`, `context.metrics.lg`.
extension AkThemeContext on BuildContext {
  AkColorTokens get colors => Theme.of(this).extension<AkColors>()!.tokens;
  AkType get type => Theme.of(this).extension<AkType>()!;
  AkMetrics get metrics => Theme.of(this).extension<AkMetrics>()!;
}
