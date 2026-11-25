import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_motion.dart';
import '../core/theme/ak_theme.dart';

/// One choice in an [AkSegmented].
class AkSegment<T> {
  const AkSegment(this.value, this.label, {this.icon, this.selectedColor});
  final T value;
  final String label;
  final AkIcons? icon;

  /// Text colour when chosen; `ink` if null. Add uses `money-out` and `money-in`.
  final Color? selectedColor;
}

/// A choice of two or three: a `surface-sunk` track with 4px padding, the chosen segment
/// in `surface-raised`, each segment at least 44px tall.
class AkSegmented<T> extends StatelessWidget {
  const AkSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  });

  final List<AkSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = context.metrics;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(AkSpace.s1),
        decoration: BoxDecoration(color: c.surfaceSunk, borderRadius: BorderRadius.circular(m.lg)),
        child: LayoutBuilder(
          builder: (context, box) {
            final (flex, labelScale) = _flexes(context, box.maxWidth);
            // Each segment's width and left edge, worked out once so the sliding thumb and
            // the labels above it line up exactly.
            final n = segments.length;
            final room = box.maxWidth - AkSpace.s1 * (n - 1);
            final sum = flex.fold<int>(0, (a, f) => a + f);
            final widths = [for (final f in flex) room * f / sum];
            final lefts = <double>[];
            var x = 0.0;
            for (final w in widths) {
              lefts.add(x);
              x += w + AkSpace.s1;
            }
            final at = segments.indexWhere((s) => s.value == selected);
            return Stack(
              children: [
                if (at >= 0)
                  // The chosen segment's raised pill slides to the new choice instead of
                  // jumping; it stays put when the phone asks for less motion.
                  AnimatedPositioned(
                    duration: AkMotion.of(context),
                    curve: AkMotion.settle,
                    left: lefts[at],
                    width: widths[at],
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        borderRadius: BorderRadius.circular(m.md),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: AkSpace.s1),
                      SizedBox(width: widths[i], child: _segment(context, segments[i], labelScale)),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Equal widths, as drawn, while every label fits its share. When one would break onto a
  /// second line but all of them fit side by side ("This month" beside "All"), each segment
  /// takes room in proportion to its label, so no label breaks while space is left beside it.
  /// When even that is too wide, the labels shrink together, at most to [_minLabelScale]
  /// (the type before it went one step up, body 14 of 16), before any breaks: on a 390 phone
  /// "Money out, Money in, Move money" beside Add's close button is a few pixels too wide.
  /// Returns the flexes and the label scale (1 unless they had to shrink).
  (List<int>, double) _flexes(BuildContext context, double width) {
    final n = segments.length;
    final equal = List<int>.filled(n, 1);
    if (!width.isFinite) return (equal, 1);
    final t = context.type;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // The chosen style is the widest, so a label fits whichever segment is chosen.
    double labelWidth(AkSegment<T> s) => (TextPainter(
      text: TextSpan(text: s.label, style: t.bodyStrong),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width;
    double chrome(AkSegment<T> s) =>
        AkSpace.s1 * 2 +
        (s.icon == null ? 0 : AkSize.iconSm + AkSpace.s2) +
        1; // rounding slack, so a label that just fits is not measured a hair short
    final labels = [for (final s in segments) labelWidth(s)];
    // Never narrower than a 44px target, so a short label ("All") stays easy to tap.
    List<double> natural(double scale) => [
      for (var i = 0; i < n; i++) math.max(AkSize.target, labels[i] * scale + chrome(segments[i])),
    ];
    final room = width - AkSpace.s1 * (n - 1);
    final share = room / n;
    List<int> proportional(List<double> widths) {
      final total = widths.fold<double>(0, (a, w) => a + w);
      // The spare room is shared out as evenly as the labels allow.
      final spare = (room - total) / n;
      return [for (final w in widths) ((w + spare) * 10).round()];
    }

    final full = natural(1);
    if (full.every((w) => w <= share)) return (equal, 1);
    final total = full.fold<double>(0, (a, w) => a + w);
    if (total <= room) return (proportional(full), 1);
    // Shrink the labels just enough to fit, never under the floor.
    final fixed = [for (var i = 0; i < n; i++) chrome(segments[i])]
        .fold<double>(0, (a, w) => a + w);
    final textTotal = labels.fold<double>(0, (a, w) => a + w);
    final scale = textTotal == 0 ? 1.0 : (room - fixed) / textTotal;
    if (scale >= _minLabelScale) {
      final shrunk = natural(scale);
      // The widths come from room, so they sum to it; allow for floating-point rounding.
      if (shrunk.fold<double>(0, (a, w) => a + w) <= room + 0.01) {
        return (proportional(shrunk), scale);
      }
    }
    return (equal, 1); // nothing fits on one line; keep the drawn even split
  }

  /// The smallest a segment label shrinks to before it may break: 14 of 16.
  static const _minLabelScale = 14 / 16;

  Widget _segment(BuildContext context, AkSegment<T> s, double labelScale) {
    final c = context.colors;
    final t = context.type;
    final on = s.value == selected;
    final colour = on ? (s.selectedColor ?? c.ink) : c.inkMuted;
    return Semantics(
      button: true,
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: Material(
        // Clear: the raised pill behind is the sliding thumb.
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(context.metrics.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.metrics.md),
          onTap: on ? null : () => onChanged(s.value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.target),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s1, vertical: AkSpace.s1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (s.icon != null) ...[
                    AkIcon(s.icon!, size: AkSize.iconSm, color: colour),
                    const SizedBox(width: AkSpace.s2),
                  ],
                  Flexible(
                    // The label's colour and weight ease over with the thumb.
                    child: AnimatedDefaultTextStyle(
                      duration: AkMotion.of(context),
                      curve: AkMotion.settle,
                      style: _scaled(
                        on ? t.bodyStrong : t.body.copyWith(fontWeight: FontWeight.w500),
                        labelScale,
                      ).copyWith(color: colour),
                      child: Text(s.label, textAlign: TextAlign.center),
                    ),
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

TextStyle _scaled(TextStyle style, double scale) =>
    scale == 1 ? style : style.copyWith(fontSize: style.fontSize! * scale);

/// A yes or no choice: a 48 by 28 track inside a 44px tall target, `switch-on` when on.
class AkSwitch extends StatelessWidget {
  const AkSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Read by screen readers; the row's visible label.
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const knob = AkSize.switchH - 4;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      toggled: value,
      label: label,
      enabled: onChanged != null,
      container: true,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: SizedBox(
          width: AkSize.switchW,
          height: AkSize.target,
          child: Center(
            child: AnimatedContainer(
              duration: reduce ? Duration.zero : AkMotion.fast,
              curve: Curves.easeOut,
              width: AkSize.switchW,
              height: AkSize.switchH,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? c.switchOn : c.switchOff,
                borderRadius: BorderRadius.circular(AkSize.switchH / 2),
              ),
              child: AnimatedAlign(
                duration: reduce ? Duration.zero : AkMotion.fast,
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(color: c.onBrand, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill chip, 44px tall: account choices on Add, filters, periods.
///
/// Unselected chips have a `line-strong` outline and an optional colour dot.
/// Selected chips are filled with [selectedFill] (an account colour, or `brand`).
class AkChip extends StatelessWidget {
  const AkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.selectedFill,
    this.selectedInk,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? dot;
  final Color? selectedFill;
  final Color? selectedInk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final fill = selected ? (selectedFill ?? c.brand) : c.surface;
    final ink = selected
        ? (selectedInk ?? (selectedFill == null ? c.onBrand : c.onLightFill))
        : c.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.metrics.pill),
      side: BorderSide(color: selected ? fill : c.lineStrong),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.target),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null && !selected) ...[
                    Container(
                      width: AkSize.dot,
                      height: AkSize.dot,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AkSpace.s1h),
                  ],
                  // A label longer than the row (large text size) wraps inside the chip
                  // instead of pushing the chip past the edge of the screen.
                  Flexible(
                    child: Text(
                      label,
                      style: t.bodySm.copyWith(
                        color: ink,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
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

/// The main button: 54px, `brand` fill, `radius-lg`, `button` text in `on-brand`.
class AkPrimaryButton extends StatelessWidget {
  const AkPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fill,
    this.ink,
  });

  final String label;
  final VoidCallback? onPressed;

  /// `accent` on a `brand` ground (Welcome, onboarding); `brand` everywhere else.
  final Color? fill;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final bg = fill ?? c.brand;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? bg : c.surfaceSunk,
        borderRadius: BorderRadius.circular(context.metrics.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.button, minWidth: double.infinity),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.type.button.copyWith(
                    color: enabled ? (ink ?? c.onBrand) : c.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary button: 48px, `line-strong` outline on `surface`.
class AkOutlineButton extends StatelessWidget {
  const AkOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final AkIcons? icon;

  /// `money-out` for a destructive action; `ink` otherwise.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colour = ink ?? c.ink;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.metrics.lg),
          side: BorderSide(color: c.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.input, minWidth: double.infinity),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    AkIcon(icon!, color: colour),
                    const SizedBox(width: AkSpace.s2),
                  ],
                  Flexible(
                    child: Text(label, style: context.type.bodyStrong.copyWith(color: colour)),
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

/// A labelled text input: the label above as an eyebrow, a 48px field with a
/// `line-strong` border and `radius-lg`.
class AkTextField extends StatelessWidget {
  const AkTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.figures = false,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  /// Tabular figures, for amounts.
  final bool figures;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    OutlineInputBorder border(Color colour, [double width = 1]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colour, width: width),
    );
    final style = (figures ? t.figure : t.bodyMd).copyWith(
      fontWeight: FontWeight.w500,
      fontSize: t.bodyMd.fontSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: AkEyebrowLabel(label)),
        const SizedBox(height: AkSpace.s1h),
        // The visible label above is the field's name for screen readers too.
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            maxLength: maxLength,
            style: style,
            cursorColor: c.brand,
            decoration: InputDecoration(
              semanticCounterText: '',
              counterText: '',
              hintText: hint,
              hintStyle: style.copyWith(color: c.inkMuted),
              errorText: errorText,
              errorStyle: t.caption.copyWith(color: c.moneyOut),
              filled: true,
              fillColor: c.surface,
              isDense: true,
              constraints: const BoxConstraints(minHeight: AkSize.input),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AkSpace.s3h,
                vertical: AkSpace.s3h,
              ),
              enabledBorder: border(c.lineStrong),
              focusedBorder: border(c.brandBright, 2),
              errorBorder: border(c.moneyOut),
              focusedErrorBorder: border(c.moneyOut, 2),
              border: border(c.lineStrong),
            ),
          ),
        ),
      ],
    );
  }
}

/// The eyebrow used as a field label, without the header role.
class AkEyebrowLabel extends StatelessWidget {
  const AkEyebrowLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.type.eyebrow.copyWith(color: context.colors.inkMuted),
  );
}

/// A compact 44px link drawn as a pill: `line-strong` outline on `surface`, an icon and a
/// label in `brand-text`. "List" on Calendar, "Calendar" on All transactions, and "Edit" on a
/// category's page, which is drawn without an icon.
class AkPillButton extends StatelessWidget {
  const AkPillButton({super.key, required this.label, this.icon, required this.onTap});

  final String label;
  final AkIcons? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(context.metrics.pill);
    return Semantics(
      button: true,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.target),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: icon == null ? AkSpace.s4 : AkSpace.s3h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon case final icon?) ...[
                    AkIcon(icon, color: c.brandText, size: AkSize.iconSm),
                    const SizedBox(width: AkSpace.s1h),
                  ],
                  Text(label, style: context.type.bodyStrong.copyWith(color: c.brandText)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round "+" that starts something new, such as a savings goal or a budget. 44px so it is
/// easy to tap. [label] says what it makes ("New savings goal"), since the icon has no words.
class AkAddButton extends StatelessWidget {
  const AkAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Its own node with its own tap: excludeSemantics drops the InkWell's action, and without
    // container the button merged into the heading beside it, leaving nothing to activate.
    return Semantics(
      button: true,
      container: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: AkSize.target,
          height: AkSize.target,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface,
            border: Border.all(color: c.lineStrong),
          ),
          child: AkIcon(AkIcons.plus, color: c.brandText),
        ),
      ),
    );
  }
}
