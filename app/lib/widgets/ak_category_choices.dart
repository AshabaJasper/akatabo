import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import '../core/theme/token_colour.dart';
import '../core/theme/tokens.g.dart' show akDarkTokens, akLightTokens;
import 'ak_surfaces.dart';

/// The twelve category colours in the drawn order, with the names screen readers say.
const List<(String token, String name)> categoryColourChoices = [
  ('cat-green', 'Green'),
  ('cat-blue', 'Blue'),
  ('cat-amber', 'Amber'),
  ('cat-purple', 'Purple'),
  ('cat-pink', 'Pink'),
  ('cat-slate', 'Slate'),
  ('cat-orange', 'Orange'),
  ('cat-teal', 'Teal'),
  ('cat-indigo', 'Indigo'),
  ('cat-brown', 'Brown'),
  ('cat-olive', 'Olive'),
  ('cat-red', 'Red'),
];

/// The icons a category can take, in the drawn order, with the names screen readers say.
const List<(String key, String name)> categoryIconChoices = [
  ('basket', 'Basket'),
  ('bus', 'Bus'),
  ('fuel', 'Fuel'),
  ('bolt', 'Lightning'),
  ('water', 'Water'),
  ('signal', 'Airtime and data'),
  ('book', 'Book'),
  ('house', 'House'),
  ('medical', 'Health'),
  ('heart', 'Heart'),
  ('people', 'Family'),
  ('gift', 'Gift'),
  ('giving', 'Giving'),
  ('eating', 'Eating out'),
  ('clothes', 'Clothes'),
  ('salon', 'Salon'),
  ('phone', 'Phone'),
  ('star', 'Fun'),
  ('farm', 'Farm'),
  ('work', 'Work'),
  ('bank', 'Bank'),
  ('wallet', 'Savings'),
  ('cash', 'Cash'),
  ('dots', 'Other'),
];

/// Names for icons a default category uses that are not in the drawn choices, so the
/// current icon can still be offered and named.
const Map<String, String> _extraIconNames = {'trend': 'Rising line', 'repeat': 'Repeat'};

/// The icon colour on a category tile. Amber, orange and olive are light enough to take the
/// dark `on-light-fill`; the rest take `on-brand`. The rule is the same in both themes, so an
/// amber tile keeps a dark icon in dark mode.
///
/// It goes by the colour the tile is actually filled with, not the stored name: under
/// "Category colours: One colour" or "Greys" an amber category is drawn in the main colour or
/// slate, and needs the light icon those take.
Color categoryIconColour(AkColorTokens c, String colourToken) {
  final fill = colourForToken(c, colourToken);
  return fill == akLightTokens.catAmber ||
          fill == akLightTokens.catOrange ||
          fill == akLightTokens.catOlive
      ? c.onLightFill
      : c.onBrand;
}

/// A category's tile: its icon in its own colour.
class AkCategoryTile extends StatelessWidget {
  const AkCategoryTile({
    super.key,
    required this.iconKey,
    required this.colourToken,
    this.size = AkSize.tile,
    this.iconSize,
  });

  final String iconKey;
  final String colourToken;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AkIconTile(
      icon: AkIcons.fromKey(iconKey),
      background: colourForToken(c, colourToken),
      foreground: categoryIconColour(c, colourToken),
      size: size,
      iconSize: iconSize,
    );
  }
}

/// A six-column grid of 44px choices, as Edit a category draws its colours and icons.
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      explicitChildNodes: true,
      child: GridView.builder(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisExtent: AkSize.target,
          mainAxisSpacing: AkSpace.s2,
          crossAxisSpacing: AkSpace.s2,
        ),
        itemCount: children.length,
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// One choice in a grid: a 44px target named for screen readers, marked when chosen.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.shape,
    required this.child,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final ShapeBorder shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: name,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: AkSize.target,
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, customBorder: shape, child: child),
        ),
      ),
    );
  }
}

/// The twelve `cat-` colours as 44px discs. The chosen disc gets an `ink` ring, set off from
/// the fill by a gap in the ground colour; each disc is named for screen readers.
class AkColourChoices extends StatelessWidget {
  const AkColourChoices({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  /// The group's name for screen readers, such as "Colour".
  final String label;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _ChoiceGrid(
      label: label,
      children: [
        for (final (token, name) in categoryColourChoices)
          _Choice(
            name: name,
            selected: token == selected,
            onTap: () => onChanged(token),
            shape: const CircleBorder(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: token == selected ? c.ink : c.ground.withValues(alpha: 0),
                  width: AkSize.stroke,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AkSpace.s0h),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // The real colour, even while Category colours is One colour or
                    // Greys, so the choice shows what Colourful will draw.
                    color: colourForToken(_colourful(context), token),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// This theme's tokens before Category colours is applied: the `cat-` tokens are the same in
/// every main colour, so the base tokens of the brightness are enough.
AkColorTokens _colourful(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? akDarkTokens : akLightTokens;

/// The category icons as 44px tiles in six columns. The chosen tile is `surface-sunk` with a
/// 2px `brand-bright` border on all sides; the rest are `surface` with a `line-strong` border.
/// An icon in use that is not among the choices, such as a default money-in icon, is added
/// at the end so it stays chosen.
class AkIconChoices extends StatelessWidget {
  const AkIconChoices({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.metrics.md);
    final choices = [
      ...categoryIconChoices,
      if (!categoryIconChoices.any((e) => e.$1 == selected))
        (selected, _extraIconNames[selected] ?? 'Current icon'),
    ];
    return _ChoiceGrid(
      label: label,
      children: [
        for (final (key, name) in choices)
          _Choice(
            name: name,
            selected: key == selected,
            onTap: () => onChanged(key),
            shape: RoundedRectangleBorder(borderRadius: radius),
            child: Ink(
              decoration: BoxDecoration(
                color: key == selected ? c.surfaceSunk : c.surface,
                borderRadius: radius,
                border: key == selected
                    ? Border.all(color: c.brandBright, width: AkSize.stroke)
                    : Border.all(color: c.lineStrong),
              ),
              child: Center(
                child: AkIcon(AkIcons.fromKey(key), size: AkSize.iconNav, color: c.ink),
              ),
            ),
          ),
      ],
    );
  }
}
