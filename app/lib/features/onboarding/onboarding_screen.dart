import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_logo.dart';
import '../../widgets/ak_surfaces.dart';
import 'reveal.dart';

/// Three short steps on `screen-deep`, then Welcome. Step one is drawn; two and three follow
/// its layout (picture above, headline and one sentence below) and are flagged for a
/// design check. The figures in the pictures are examples, not the person's.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const steps = 3;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toWelcome() => context.push(Routes.welcome);

  void _next() {
    if (_page == OnboardingScreen.steps - 1) {
      _toWelcome();
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: c.screenDeep.withValues(alpha: 0),
        systemNavigationBarColor: c.screenDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.screenDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Expanded, so at a large text size the name ellipsises instead of
                    // pushing Skip off the screen.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AkLogo(style: t.titleLg.copyWith(color: c.onBrand)),
                      ),
                    ),
                    _TextButton('Skip', onTap: _toWelcome),
                  ],
                ),
                const SizedBox(height: AkSpace.s5),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: const [_AddStep(), _SplitStep(), _PrivateStep()],
                  ),
                ),
                const SizedBox(height: AkSpace.s5),
                Row(
                  children: [
                    _Dots(count: OnboardingScreen.steps, current: _page),
                    const Spacer(),
                    _NextButton(onTap: _next),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A step: the picture, then the headline and one sentence. Scrolls at large text sizes.
class _Step extends StatelessWidget {
  const _Step({required this.title, required this.body, required this.picture});

  final String title;
  final String body;
  final List<Widget> Function(Animation<double> clock) picture;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return RevealGroup(
      builder: (context, clock) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, part) in picture(clock).indexed) ...[
                        if (i > 0) const SizedBox(height: AkSpace.s3),
                        part,
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AkSpace.s6),
                Reveal(
                  clock: clock,
                  delay: 0.15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: t.figureLg.copyWith(color: c.onBrandFigure)),
                      ),
                      const SizedBox(height: AkSpace.s2h),
                      Text(body, style: t.bodyLg.copyWith(color: c.onDeep)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddStep extends StatelessWidget {
  const _AddStep();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return _Step(
      title: 'Add it in seconds',
      body: 'Type an amount and a few words. Akatabo suggests the category, and you tap save.',
      picture: (clock) => [
        Reveal(
          clock: clock,
          delay: 0,
          pop: true,
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AkEyebrowLabel('Amount, UGX'),
                const SizedBox(height: AkSpace.s1),
                Text('45,000', style: t.figureXl.copyWith(color: c.ink)),
              ],
            ),
          ),
        ),
        Reveal(
          clock: clock,
          delay: 0.35,
          child: _Card(
            child: Text('Groceries, Nakasero market', style: t.bodyMd.copyWith(color: c.ink)),
          ),
        ),
        Reveal(
          clock: clock,
          delay: 0.75,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(minHeight: AkSize.target),
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(context.metrics.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AkIcon(AkIcons.basket, color: c.onLightFill),
                  const SizedBox(width: AkSpace.s2h),
                  Flexible(
                    child: Text(
                      'Food and shopping, 87% sure',
                      style: t.bodyStrong.copyWith(color: c.onLightFill),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Reveal(
          clock: clock,
          delay: 1.15,
          child: Row(
            children: [
              AkIcon(AkIcons.check, color: c.accent, strokeWidth: 2.5),
              const SizedBox(width: AkSpace.s2),
              Flexible(
                child: Text(
                  'Saved in about five seconds',
                  style: t.body.copyWith(color: c.onBrandMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final rows = [
      ('Food and shopping', AkIcons.basket, c.catGreen, c.onBrand, 0.38, '38%'),
      ('Transport', AkIcons.bus, c.catAmber, c.onLightFill, 0.21, '21%'),
      ('Bills', AkIcons.bolt, c.catPurple, c.onBrand, 0.14, '14%'),
    ];
    return _Step(
      title: 'See where it went',
      body:
          'Every entry lands in a category, so the month splits into where your money '
          'actually went.',
      picture: (clock) => [
        Reveal(
          clock: clock,
          delay: 0,
          pop: true,
          child: _Card(
            child: Column(
              children: [
                for (final (i, (name, icon, fill, ink, share, label)) in rows.indexed) ...[
                  if (i > 0) const SizedBox(height: AkSpace.s3),
                  Row(
                    children: [
                      AkIconTile(
                        icon: icon,
                        background: fill,
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
                                  child: Text(name, style: t.bodyStrong.copyWith(color: c.ink)),
                                ),
                                Text(label, style: t.figure.copyWith(color: c.ink)),
                              ],
                            ),
                            const SizedBox(height: AkSpace.s1),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(context.metrics.sm),
                              child: SizedBox(
                                height: AkSize.bar,
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: ColoredBox(color: c.surfaceSunk)),
                                    FractionallySizedBox(
                                      widthFactor: share,
                                      child: ColoredBox(color: fill),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Reveal(
          clock: clock,
          delay: 0.55,
          child: Row(
            children: [
              AkIcon(AkIcons.trend, color: c.accent),
              const SizedBox(width: AkSpace.s2),
              Flexible(
                child: Text(
                  '12% above this point last month',
                  style: t.body.copyWith(color: c.onBrandMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivateStep extends StatelessWidget {
  const _PrivateStep();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final facts = [
      (AkIcons.phone, 'Your entries are kept on this phone'),
      (AkIcons.lock, 'No account to make, no adverts'),
      (AkIcons.download, 'Back up to a file you keep'),
    ];
    return _Step(
      title: 'Yours, on this phone',
      body:
          'Akatabo works offline and uploads nothing. You can export or delete your data at '
          'any time.',
      picture: (clock) => [
        for (final (i, (icon, text)) in facts.indexed)
          Reveal(
            clock: clock,
            delay: i == 0 ? 0 : 0.35 + 0.2 * i,
            pop: i == 0,
            child: _Card(
              child: Row(
                children: [
                  AkIconTile(icon: icon, background: c.brand, foreground: c.accent),
                  const SizedBox(width: AkSpace.s3),
                  Expanded(
                    child: Text(text, style: t.bodyMd.copyWith(color: c.ink)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A white card on `screen-deep` (surface in dark), as the drawn step one shows.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AkSpace.s4),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(context.metrics.lg),
    ),
    child: child,
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Step ${current + 1} of $count',
      container: true,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: AkSpace.s1h),
            AnimatedContainer(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
              width: i == current ? AkSize.switchH : AkSpace.s2,
              height: AkSpace.s2,
              decoration: BoxDecoration(
                color: i == current ? c.accent : c.deepLine,
                borderRadius: BorderRadius.circular(context.metrics.xs),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Next',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.accent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AkSize.button),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Next', style: context.type.button.copyWith(color: c.onLightFill)),
                  const SizedBox(width: AkSpace.s2),
                  AkIcon(AkIcons.arrow, color: c.onLightFill, strokeWidth: 2.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    container: true,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AkSize.target, minWidth: AkSize.target),
        child: Center(
          child: Text(
            label,
            style: context.type.bodyStrong.copyWith(color: context.colors.onBrandMuted),
          ),
        ),
      ),
    ),
  );
}
