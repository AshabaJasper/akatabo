import 'package:material_ui/material_ui.dart';

/// A page transition that stands still when the phone asks for less motion (Android's
/// "Remove animations", iOS's "Reduce motion"): the new screen appears at once. It still
/// goes through the platform's own transition, only with animations that are already
/// finished, because on iOS that transition is what adds the swipe-back gesture.
class StillWhenReduced extends PageTransitionsBuilder {
  const StillWhenReduced();

  static const _platformDefault = PageTransitionsTheme();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return _platformDefault.buildTransitions(
      route,
      context,
      still ? kAlwaysCompleteAnimation : animation,
      still ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
  }
}
