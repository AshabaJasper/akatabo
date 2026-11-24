import 'package:material_ui/material_ui.dart';

import '../core/brand/akatabo_mark.dart';
import '../core/theme/ak_theme.dart';
import '../core/theme/tokens.g.dart';

/// Where the logo sits, which decides its colours.
enum AkLogoOn {
  /// On the brand-green header: a paper cover with a dark line.
  brand,

  /// On the screen ground: a green cover with the accent line in light mode, the paper
  /// cover in dark mode so it stays visible.
  ground,
}

/// The Akatabo logo: the notebook mark (`lib/core/brand/akatabo_mark.dart`), optionally
/// followed by the wordmark in [style]. The mark is sized from [style]'s font size, so it
/// follows the text-size setting. Screen readers hear "Akatabo" once.
class AkLogo extends StatelessWidget {
  const AkLogo({super.key, required this.style, this.on = AkLogoOn.brand, this.wordmark = true});

  /// The wordmark's style. Its colour is used for the mark's cover on brand.
  final TextStyle style;
  final AkLogoOn on;
  final bool wordmark;

  /// The mark's side as a share of the wordmark's font size: about one and a quarter cap
  /// heights taller than the capitals, as drawn in `design/brand/akatabo-lockup.svg`.
  static const double markToFontSize = 1.3;

  /// The gap between mark and wordmark as a share of the font size.
  static const double gapToFontSize = 0.35;

  static AkMarkColours coloursFor(BuildContext context, AkLogoOn on, {Color? cover}) {
    final c = context.colors;
    // The page block is always the bright brand green, the one drawn in the mark.
    final page = akDarkTokens.brandBright;
    switch (on) {
      case AkLogoOn.brand:
        return AkMarkInColour(cover: cover ?? c.onBrand, page: page, line: c.brandDeep);
      case AkLogoOn.ground:
        return Theme.of(context).brightness == Brightness.dark
            ? AkMarkInColour(cover: akLightTokens.ground, page: page, line: akLightTokens.brandDeep)
            : AkMarkInColour(
                cover: akLightTokens.brandDeep,
                page: page,
                line: akLightTokens.accent,
              );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? AkTextTokens.titleLg.size);
    final mark = CustomPaint(
      size: Size.square(fontSize * markToFontSize),
      painter: AkMarkPainter(coloursFor(context, on, cover: style.color)),
    );
    if (!wordmark) {
      return Semantics(label: 'Akatabo', image: true, child: mark);
    }
    return Semantics(
      label: 'Akatabo',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: fontSize * gapToFontSize),
          Flexible(
            child: Text('Akatabo', style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
