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

/// "Text size" on Settings > Appearance. The drawn buttons are 13, 14 and 16px, so the
/// factors are 13/14 and 16/14. The phone's own text size still applies on top.
enum AkTextSize {
  small(13 / 14),
  standard(1),
  large(16 / 14);

  const AkTextSize(this.factor);
  final double factor;
}

/// Everything on the Appearance page that changes how the theme is built.
class AkAppearance {
  const AkAppearance({
    this.themeMode = ThemeMode.system,
    this.paletteId = 'green',
    this.corners = AkCorners.rounded,
    this.textSize = AkTextSize.standard,
  });

  final ThemeMode themeMode;

  /// An `AkPalette.id` from tokens.json; `green` is the drawn default.
  final String paletteId;
  final AkCorners corners;
  final AkTextSize textSize;

  AkAppearance copyWith({
    ThemeMode? themeMode,
    String? paletteId,
    AkCorners? corners,
    AkTextSize? textSize,
  }) => AkAppearance(
    themeMode: themeMode ?? this.themeMode,
    paletteId: paletteId ?? this.paletteId,
    corners: corners ?? this.corners,
    textSize: textSize ?? this.textSize,
  );

  @override
  bool operator ==(Object other) =>
      other is AkAppearance &&
      other.themeMode == themeMode &&
      other.paletteId == paletteId &&
      other.corners == corners &&
      other.textSize == textSize;

  @override
  int get hashCode => Object.hash(themeMode, paletteId, corners, textSize);
}
