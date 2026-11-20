import 'dart:async';

import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../services/security/lock_controller.dart';
import '../../services/security/privacy_settings.dart';
import '../../services/security/privacy_window.dart';
import 'lock_screen.dart';

/// Wraps the whole app in the app builder. While locked (or while start-up has not yet
/// decided) the app is kept alive but offstage: not painted, not reachable by touch or by a
/// screen reader, and the lock screen covers it. It is not a route, so no navigation can get
/// around it.
///
/// It also keeps "Blank the screen in the app switcher" applied, at start-up and whenever the
/// setting changes.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child, required this.onWiped});

  final Widget child;

  /// After "Forgot your PIN?" has deleted everything.
  final VoidCallback onWiped;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  final _lockNavigatorKey = GlobalKey<NavigatorState>();
  bool? _blankApplied;

  @override
  void initState() {
    super.initState();
    // Registered before the router's own back handling (this widget is built first), so
    // while locked the back button and back gesture reach the lock, not the pages behind it.
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(lockControllerProvider.notifier).wentAway(),
      onShow: () => ref.read(lockControllerProvider.notifier).cameBack(),
    );
    ref.listenManual(lockControllerProvider, (_, next) {
      if (next != LockStatus.unlocked) FocusManager.instance.primaryFocus?.unfocus();
    });
    ref.listenManual(storedSettingsProvider, (_, next) {
      final s = next.value;
      if (s == null) return;
      unawaited(
        _applyBlank(PrivacyKeys.blankInSwitcher.decode(s[PrivacyKeys.blankInSwitcher.name])),
      );
    }, fireImmediately: true);
  }

  Future<void> _applyBlank(bool blank) async {
    if (_blankApplied == blank) return;
    _blankApplied = blank;
    try {
      await ref.read(privacyWindowProvider).setHiddenInRecents(blank);
    } on Object catch (error, stack) {
      _blankApplied = null; // Tried again on the next settings change.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo privacy'),
      );
    }
  }

  bool get _covered => ref.read(lockControllerProvider) != LockStatus.unlocked;

  /// While locked, back closes the lock screen's own dialog if one is open and otherwise does
  /// nothing: the pages behind stay as they were.
  @override
  Future<bool> didPopRoute() async {
    if (!_covered) return false;
    await _lockNavigatorKey.currentState?.maybePop();
    return true;
  }

  /// Claims the predictive back gesture while locked, so it never animates a page behind.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _covered;

  @override
  void handleCommitBackGesture() {
    if (_covered) unawaited(_lockNavigatorKey.currentState?.maybePop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(lockControllerProvider);
    final open = status == LockStatus.unlocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: open,
          // Out of focus as well as out of sight: no hardware keyboard or hidden text field
          // can reach the app while it is covered.
          child: ExcludeFocus(
            excluding: !open,
            child: Offstage(offstage: !open, child: widget.child),
          ),
        ),
        if (status == LockStatus.checking)
          ColoredBox(color: context.colors.screenDeep)
        else if (status == LockStatus.locked)
          // Its own navigator, so the "Forgot your PIN?" dialog opens over the lock screen
          // and never on the app's navigator behind it.
          HeroControllerScope.none(
            child: Navigator(
              key: _lockNavigatorKey,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => LockScreen(onWiped: widget.onWiped),
              ),
            ),
          ),
      ],
    );
  }
}
