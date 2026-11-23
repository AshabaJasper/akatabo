import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/ak_theme.dart';
import '../core/time/clock_provider.dart';
import '../data/settings/setting_keys.dart';
import '../features/lock/lock_gate.dart';
import '../features/onboarding/onboarding_providers.dart';
import '../features/settings/home_layout.dart';
import 'appearance.dart';
import 'router.dart';
import 'routes.dart';

/// The app root: theme from tokens and Appearance settings, and the router.
class AkataboApp extends ConsumerStatefulWidget {
  const AkataboApp({super.key, this.router, this.onboardingDone, this.opensOn});

  /// Tests pass their own router; the app builds one.
  final GoRouter? router;

  /// Read straight from the database at start-up, so a slow settings load never sends a
  /// returning person back through Onboarding. Null falls back to the settings provider.
  final bool? onboardingDone;

  /// "The app opens on", read at start-up the same way. Null falls back to the provider.
  final AppOpensOn? opensOn;

  @override
  ConsumerState<AkataboApp> createState() => _AkataboAppState();
}

class _AkataboAppState extends ConsumerState<AkataboApp> {
  bool get _onboardingDone => widget.onboardingDone ?? ref.read(onboardingDoneProvider);
  AppOpensOn get _opensOn => widget.opensOn ?? ref.read(opensOnProvider);

  /// A first launch opens on Onboarding; every later one on the screen "The app opens on"
  /// names. Settings are read before the first frame, so this is known in time and Home never
  /// flashes first.
  late final GoRouter _router =
      widget.router ??
      buildRouter(
        initialLocation: !_onboardingDone
            ? Routes.onboarding
            : _opensOn == AppOpensOn.insights
            ? Routes.insights
            : Routes.home,
      );

  /// A phone that slept past midnight may not have run the day timer, so coming back to the
  /// app works out "today" again.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(appNowProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // Start listening now; `late` would otherwise wait for the first use.
    // Add opens over Home rather than in its place, so closing it or saving lands on Home.
    if (widget.router == null && _onboardingDone && _opensOn == AppOpensOn.add) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_router.push(Routes.add));
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp.router(
      title: 'Akatabo',
      debugShowCheckedModeBanner: false,
      theme: buildAkTheme(Brightness.light, appearance),
      darkTheme: buildAkTheme(Brightness.dark, appearance),
      themeMode: appearance.themeMode,
      routerConfig: _router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: context.colors.ground.withValues(alpha: 0),
            systemNavigationBarColor: context.colors.surface,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          // The app lock covers everything the router shows (lib/features/lock).
          child: LockGate(onWiped: () => _router.go(Routes.settingsData), child: child!),
        );
      },
    );
  }
}
