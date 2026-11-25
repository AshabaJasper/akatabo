import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import '../core/theme/ak_theme.dart';

/// Whether the window is wide enough for the navigation rail and two panes. This is Material's
/// "expanded" class: a tablet in landscape, an unfolded foldable and a desktop window qualify,
/// and so do many phones turned on their side (a 411 by 914dp phone is 914dp wide). A phone
/// held upright never does.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= AkSize.wide;

/// Where the shell's content sits in the window on a wide screen: beside the rail, capped at
/// [AkSize.contentMax] and centred in what is left. The shell sets it, so panes can line up with
/// a fold in the window's own coordinates.
class ContentFrame extends InheritedWidget {
  const ContentFrame({super.key, required this.left, required this.width, required super.child});

  /// Distance from the window's left edge to the content.
  final double left;

  /// The content's width.
  final double width;

  static ContentFrame? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ContentFrame>();

  @override
  bool updateShouldNotify(ContentFrame oldWidget) =>
      left != oldWidget.left || width != oldWidget.width;
}

/// The fold or hinge that runs top to bottom (a phone open flat, like a book), in window
/// coordinates. Null when there is none.
Rect? verticalHingeOf(BuildContext context) => _hingeOf(context, vertical: true);

/// The fold or hinge that runs side to side (a phone half-open, like a laptop), in window
/// coordinates. Null when there is none.
Rect? horizontalHingeOf(BuildContext context) => _hingeOf(context, vertical: false);

Rect? _hingeOf(BuildContext context, {required bool vertical}) {
  for (final feature in MediaQuery.displayFeaturesOf(context)) {
    if (feature.type != DisplayFeatureType.hinge && feature.type != DisplayFeatureType.fold) {
      continue;
    }
    final b = feature.bounds;
    // A fold is often reported with no width or no height. Like Flutter's own
    // DisplayFeatureSubScreen, keep it when it has size or when the phone is half-open.
    if (b.shortestSide <= 0 && feature.state != DisplayFeatureState.postureHalfOpened) continue;
    final isVertical = b.width == 0 ? true : (b.height == 0 ? false : b.height > b.width);
    if (isVertical == vertical) return b;
  }
  return null;
}

/// Two panes side by side on a wide screen. A vertical hinge through the content sets the
/// split: the left pane ends at the hinge and the right starts after it, so nothing is drawn
/// across the fold. Without a hinge the panes take their own shares of the width.
class WidePanes extends StatelessWidget {
  const WidePanes({super.key, required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final frame = ContentFrame.maybeOf(context);
    final left = frame?.left ?? 0;
    final width = frame?.width ?? MediaQuery.sizeOf(context).width;
    final hinge = verticalHingeOf(context);

    if (hinge != null && hinge.left > left && hinge.right < left + width) {
      return Row(
        children: [
          SizedBox(width: hinge.left - left, child: primary),
          SizedBox(width: hinge.width),
          Expanded(child: secondary),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 2, child: primary),
        SizedBox(width: 1, child: ColoredBox(color: context.colors.line)),
        Expanded(flex: 3, child: secondary),
      ],
    );
  }
}

/// Keeps content off a horizontal fold. A phone half-open like a laptop keeps the content on
/// the half the hinge does not cut through. The space is kept a little generous: the bottom
/// edge uses the whole window height, so the content stops a bar's height above the hinge.
class HingeSafe extends StatelessWidget {
  const HingeSafe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hinge = horizontalHingeOf(context);
    if (hinge == null) return child;
    final height = MediaQuery.sizeOf(context).height;
    if (hinge.center.dy < height / 2) {
      return Padding(
        padding: EdgeInsets.only(top: math.min(hinge.bottom, height)),
        child: child,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: math.max(0, height - hinge.top)),
      child: child,
    );
  }
}
