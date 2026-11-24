import 'package:material_ui/material_ui.dart' show ThemeMode;

/// "Corners" on Settings > Appearance. The factor multiplies every radius token.
///
/// The drawn "Slight" button has a 4px corner where "Rounded" has 10px, so Slight is 0.4.
enum AkCorners {
  rounded(1),
  slight(0.4),
  square(0);

  const AkCorners(this.factor);
  final double factor;
}

/// "Text size" on Settings > Appearance. The type tokens went one step up on 24 Nov 2026
/// (body 14 to 16), so Small is the old Standard (body 14, 14/16) and Large is one more
/// step (body 18, 18/16). The phone's own text size still applies on top.
enum AkTextSize {
  small(14 / 16),
  standard(1),
  large(18 / 16);

  const AkTextSize(this.factor);
  final double factor;
}

/// "Category colours" on Settings > Appearance: each category in its own colour, all in the
/// main colour, or all in grey. Only the screen changes; each category keeps its stored colour,
/// so switching back to Colourful brings every one back.
enum AkCategoryColours { colourful, oneColour, greys }

/// "Money colours" on Settings > Appearance: money out in red and money in in green (the
/// default, which the owner asked for), or the drawn orange and blue, which stay apart for
/// colour-blind eyes. Signs and arrows travel with both, so colour is never the only cue.
enum AkMoneyColours { redGreen, orangeBlue }

/// Everything on the Appearance page that changes how the theme is built.
class AkAppearance {
  const AkAppearance({
    this.themeMode = ThemeMode.system,
    this.paletteId = 'green',
    this.corners = AkCorners.rounded,
    this.textSize = AkTextSize.standard,
    this.categoryColours = AkCategoryColours.colourful,
    this.moneyColours = AkMoneyColours.redGreen,
  });

  final ThemeMode themeMode;

  /// An `AkPalette.id` from tokens.json; `green` is the drawn default.
  final String paletteId;
  final AkCorners corners;
  final AkTextSize textSize;
  final AkCategoryColours categoryColours;
  final AkMoneyColours moneyColours;

  AkAppearance copyWith({
    ThemeMode? themeMode,
    String? paletteId,
    AkCorners? corners,
    AkTextSize? textSize,
    AkCategoryColours? categoryColours,
    AkMoneyColours? moneyColours,
  }) => AkAppearance(
    themeMode: themeMode ?? this.themeMode,
    paletteId: paletteId ?? this.paletteId,
    corners: corners ?? this.corners,
    textSize: textSize ?? this.textSize,
    categoryColours: categoryColours ?? this.categoryColours,
    moneyColours: moneyColours ?? this.moneyColours,
  );

  @override
  bool operator ==(Object other) =>
      other is AkAppearance &&
      other.themeMode == themeMode &&
      other.paletteId == paletteId &&
      other.corners == corners &&
      other.textSize == textSize &&
      other.categoryColours == categoryColours &&
      other.moneyColours == moneyColours;

  @override
  int get hashCode =>
      Object.hash(themeMode, paletteId, corners, textSize, categoryColours, moneyColours);
}
