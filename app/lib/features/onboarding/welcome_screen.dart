import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_surfaces.dart';
import 'onboarding_providers.dart';

/// The last first-launch screen: what Akatabo does, then add a first entry or look around.
/// Either choice marks Onboarding as done.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _busy = false;

  Future<void> _finish({required bool addFirst}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await finishOnboarding(ref);
    } on Object catch (error, stack) {
      // Not saving the flag only means Onboarding shows again next time; carry on.
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    }
    if (!mounted) return;
    final router = GoRouter.of(context)..go(Routes.home);
    // Add opens over Home, so closing it lands on Home.
    if (addFirst) unawaited(router.push(Routes.add));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    const points = [
      (AkIcons.plus, 'Type an amount and a few words. The category fills itself in.'),
      (AkIcons.chip, 'It forecasts your month and warns you before a budget runs out.'),
      // The drawn line says "no permissions"; reminders and fingerprint unlock each ask for
      // one when switched on, so this says what is true instead (flagged in PROGRESS.md).
      (AkIcons.lock, 'Everything stays on this phone. No account, no adverts, nothing uploaded.'),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: c.screenDeep.withValues(alpha: 0),
        systemNavigationBarColor: c.screenDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.screenDeep,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s6, AkSpace.s6, AkSpace.s6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - AkSpace.s6 * 2),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A Wrap, so at a large text size the badge moves under the name
                      // instead of running off the screen.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AkSpace.s3,
                        runSpacing: AkSpace.s2,
                        children: [
                          Text('Akatabo', style: t.titleLg.copyWith(color: c.onBrand)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AkSpace.s3,
                              vertical: AkSpace.s1h,
                            ),
                            decoration: BoxDecoration(
                              color: c.brandRaised,
                              borderRadius: BorderRadius.circular(context.metrics.pill),
                            ),
                            child: Text(
                              'UGX 0, always',
                              style: t.captionStrong.copyWith(color: c.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AkSpace.s6),
                      Semantics(
                        header: true,
                        child: Text(
                          'Know where your money goes.',
                          style: t.displayXl.copyWith(color: c.onBrand),
                        ),
                      ),
                      const SizedBox(height: AkSpace.s3h),
                      Text(
                        'Add what you spend in a few seconds. Akatabo sorts it, totals it and '
                        'shows where the month is heading, across cash, mobile money and bank.',
                        style: t.bodyLg.copyWith(color: c.onDeep),
                      ),
                      const SizedBox(height: AkSpace.s6),
                      for (final (i, (icon, text)) in points.indexed) ...[
                        if (i > 0) const SizedBox(height: AkSpace.s3h),
                        Row(
                          children: [
                            AkIconTile(
                              icon: icon,
                              background: c.brandRaised,
                              foreground: c.accent,
                              size: AkSize.tileMd,
                            ),
                            const SizedBox(width: AkSpace.s3h),
                            Expanded(
                              child: Text(
                                text,
                                style: t.bodyMd.copyWith(
                                  color: c.onBrand,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AkSpace.s6),
                      const Spacer(),
                      _WelcomeButton(
                        label: 'Add my first transaction',
                        filled: true,
                        onTap: _busy ? null : () => _finish(addFirst: true),
                      ),
                      const SizedBox(height: AkSpace.s3),
                      _WelcomeButton(
                        label: 'Look around first',
                        filled: false,
                        onTap: _busy ? null : () => _finish(addFirst: false),
                      ),
                      const SizedBox(height: AkSpace.s3),
                      Text(
                        'Works offline. You can export or delete your data at any time.',
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(color: c.onBrandMuted),
                      ),
                    ],
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

/// The two Welcome actions: `accent` filled, or outlined on `screen-deep`.
class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({required this.label, required this.filled, required this.onTap});

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: filled ? c.accent : c.screenDeep,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled ? BorderSide.none : BorderSide(color: c.onBrandMuted),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: filled ? AkSize.button : AkSize.input),
            child: Center(
              child: Text(
                label,
                style: filled
                    ? t.button.copyWith(color: c.onLightFill)
                    : t.bodyMd.copyWith(color: c.onBrand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
