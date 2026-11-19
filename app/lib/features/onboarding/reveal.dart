import 'package:material_ui/material_ui.dart';

/// The Onboarding entrance, as the design's CSS draws it: each part rises 18px and fades in
/// (or pops from 82% scale for the main card), one after another. Skipped entirely when the
/// phone asks for reduced motion.
class RevealGroup extends StatefulWidget {
  const RevealGroup({super.key, required this.builder});

  /// Builds the content; wrap each part in [Reveal] with its place in the order.
  final Widget Function(BuildContext context, Animation<double> clock) builder;

  @override
  State<RevealGroup> createState() => _RevealGroupState();
}

class _RevealGroupState extends State<RevealGroup> with SingleTickerProviderStateMixin {
  // The last part starts at 1.4s and runs 0.55s, as in the design.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1950),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (!_clock.isAnimating && _clock.value == 0) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _clock);
}

/// One part of a [RevealGroup]. [delay] is in seconds from the group's start.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.clock,
    required this.delay,
    required this.child,
    this.pop = false,
  });

  final Animation<double> clock;
  final double delay;
  final bool pop;
  final Widget child;

  static const _total = 1.95;
  static const _length = 0.55;
  static const _rise = 18.0;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: clock,
      curve: Interval(delay / _total, (delay + _length) / _total, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = t.value;
        return Opacity(
          opacity: v.clamp(0, 1),
          child: pop
              ? Transform.scale(scale: 0.82 + 0.18 * v, child: child)
              : Transform.translate(offset: Offset(0, _rise * (1 - v)), child: child),
        );
      },
    );
  }
}
