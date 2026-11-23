import 'package:material_ui/material_ui.dart';

/// How fast small things move: a switch knob, a segmented control's thumb. The design's
/// Motion rule asks for quick, plain movement that stops at once when the phone's "Remove
/// animations" setting is on.
abstract final class AkMotion {
  /// A control changing state.
  static const fast = Duration(milliseconds: 160);

  /// The one pulse on a forecast's "today" point (DESIGN_SYSTEM.md, Motion). It plays once.
  static const pulse = Duration(milliseconds: 1200);

  /// Starts quickly and settles: things arrive rather than bounce.
  static const Curve settle = Curves.easeOutCubic;

  /// [duration], or no time at all when the person has asked for less motion.
  static Duration of(BuildContext context, [Duration duration = fast]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
