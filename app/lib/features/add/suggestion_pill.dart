import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';

/// "Suggested: Food and shopping, 87% sure", as Transaction.html draws it: an accent pill
/// with the chip icon beside the Category heading. The drawn pill is 28px tall; the tap area
/// around it is the 44px minimum. Tapping it chooses the category.
class SuggestionPill extends StatelessWidget {
  const SuggestionPill({
    super.key,
    required this.categoryName,
    required this.probability,
    required this.selected,
    required this.onTap,
  });

  final String categoryName;

  /// 0 to 1.
  final double probability;
  final bool selected;
  final VoidCallback onTap;

  /// Whole percent, never 100: a suggestion is never certain.
  static int percentOf(double probability) => (probability * 100).round().clamp(0, 99);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final label = 'Suggested: $categoryName, ${percentOf(probability)}% sure';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: selected ? null : 'Choose this category',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.metrics.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.target),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: AkSize.pill),
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2h, vertical: AkSpace.s1),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(context.metrics.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AkIcon(AkIcons.chip, color: c.onLightFill, size: AkSize.iconXs),
                  const SizedBox(width: AkSpace.s1h),
                  Flexible(
                    child: Text(label, style: t.captionStrong.copyWith(color: c.onLightFill)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
