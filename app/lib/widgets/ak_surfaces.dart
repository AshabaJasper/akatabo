import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';

/// A `surface` card: 1px `line` border, `radius-lg`, no shadow, `space-4` padding.
class AkCard extends StatelessWidget {
  const AkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AkSpace.s4),
    this.onTap,
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.metrics.lg);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: borderColor ?? c.line),
    );
    final body = Padding(padding: padding, child: child);
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : Semantics(
              button: true,
              label: semanticLabel,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// A square tile holding an icon: category tiles, settings tiles, the forecast tile.
class AkIconTile extends StatelessWidget {
  const AkIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = AkSize.tile,
    this.iconSize,
  });

  final AkIcons icon;
  final Color background;
  final Color foreground;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(context.metrics.md),
      ),
      child: AkIcon(icon, size: iconSize ?? size * 0.55, color: foreground),
    );
  }
}

/// A 48 to 52px list row: a tile, a two-line text block and a right-aligned value.
class AkListRow extends StatelessWidget {
  const AkListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.divider = false,
    this.minHeight = AkSize.row,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A 1px `line` under the row, as between rows in a list.
  final bool divider;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final row = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            )
          : null,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AkSpace.s3)],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AkSpace.s1h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.body.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle!, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AkSpace.s3), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A section eyebrow or field label: `caption`, uppercase, tracked, `ink-muted`.
class AkEyebrow extends StatelessWidget {
  const AkEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: context.type.eyebrow.copyWith(color: context.colors.inkMuted),
    ),
  );
}

/// A section heading in `title`, with an optional "See all" style link on the right.
class AkSectionTitle extends StatelessWidget {
  const AkSectionTitle(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: context.type.title)),
        ),
        if (actionLabel != null) AkTextLink(actionLabel!, onTap: onAction),
      ],
    );
  }
}

/// A text link in `brand-text`, 44px tall so it is easy to tap.
class AkTextLink extends StatelessWidget {
  const AkTextLink(this.label, {super.key, this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final AkIcons? icon;

  @override
  Widget build(BuildContext context) {
    final colour = context.colors.brandText;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.metrics.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.target, minWidth: AkSize.target),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AkIcon(icon!, color: colour),
                const SizedBox(width: AkSpace.s1h),
              ],
              Text(
                label,
                style: context.type.bodySm.copyWith(color: colour, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The back link at the top of a sub-page. It names the screen the person came from.
class AkBackLink extends StatelessWidget {
  const AkBackLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = context.colors.brandText;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: 'Back to $label',
        container: true,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.metrics.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.target),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AkIcon(AkIcons.back, color: colour),
                const SizedBox(width: AkSpace.s1h),
                Text(
                  label,
                  style: context.type.body.copyWith(color: colour, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
