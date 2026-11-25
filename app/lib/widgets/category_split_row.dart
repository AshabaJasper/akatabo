import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format/money.dart';
import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import '../core/theme/token_colour.dart';
import '../data/db/app_database.dart';
import 'ak_category_choices.dart';
import 'ak_hidden_amount.dart';
import 'ak_surfaces.dart';

/// One category's part of money out: its icon, name, amount, share and a bar relative to
/// the largest part shown. Home's "Where it went" and the calendar's top categories use it.
/// With [onTap] the whole row opens something, such as the category.
class CategorySplitRow extends ConsumerWidget {
  const CategorySplitRow({
    super.key,
    required this.category,
    required this.amount,
    required this.share,
    required this.fraction,
    this.onTap,
  });

  final Category? category;
  final int amount;
  final double share;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final hidden = ref.watch(amountsHiddenProvider);
    final amountText = hidden ? hiddenFigure : formatAmount(amount);
    final name = category?.name ?? 'Other';
    final colour = colourForToken(c, category?.colourToken ?? 'cat-slate');
    final ink = categoryIconColour(c, category?.colourToken ?? 'cat-slate');
    final shareText = formatPercent(share);

    return Semantics(
      label: '$name, ${hidden ? 'amount hidden' : amountText}, $shareText of money out',
      container: true,
      button: onTap != null,
      // The tap goes on this node: excludeSemantics drops the InkWell's own action.
      onTap: onTap,
      excludeSemantics: true,
      child: _Tappable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s2h),
          child: Row(
            children: [
              AkIconTile(
                icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
                background: colour,
                foreground: ink,
                size: AkSize.tileSm,
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySm.copyWith(color: c.ink),
                          ),
                        ),
                        Text(amountText, style: t.figure.copyWith(color: c.ink)),
                        const SizedBox(width: AkSpace.s1),
                        Text(shareText, style: t.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: AkSpace.s1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AkSize.bar),
                      child: Stack(
                        children: [
                          Container(height: AkSize.bar, color: c.line),
                          FractionallySizedBox(
                            widthFactor: fraction.clamp(0, 1),
                            child: Container(height: AkSize.bar, color: colour),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Makes [child] tappable when [onTap] is set, with the usual ink splash.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => onTap == null
      ? child
      : InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.metrics.sm),
          // A row that opens something is at least a 44px target; a plain row keeps the
          // drawn height.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.target),
            child: child,
          ),
        );
}
