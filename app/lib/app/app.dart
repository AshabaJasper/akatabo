import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/ak_theme.dart';
import 'appearance.dart';
import 'router.dart';

/// The app root: theme from tokens and Appearance settings, and the router.
class AkataboApp extends ConsumerStatefulWidget {
  const AkataboApp({super.key, this.router});

  /// Tests pass their own router; the app builds one.
  final GoRouter? router;

  @override
  ConsumerState<AkataboApp> createState() => _AkataboAppState();
}

class _AkataboAppState extends ConsumerState<AkataboApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  void dispose() {
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
          child: child!,
        );
      },
    );
  }
}
