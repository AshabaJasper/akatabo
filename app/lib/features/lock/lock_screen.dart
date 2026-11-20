import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../services/security/biometrics.dart';
import '../../services/security/lock_controller.dart';
import '../../services/security/pin_store.dart';
import '../../services/security/privacy_settings.dart';
import 'pin_panel.dart';

/// The help line under the dots, as drawn.
const lockHelp = 'Your money details stay hidden until you unlock.';

/// What a wrong PIN says. Waits are spelled out so the person knows how long.
String wrongPinMessage(PinRejected r) {
  if (r.wait > Duration.zero) return 'That PIN is not right. ${waitMessage(r.wait)}';
  if (r.triesBeforeWait <= 2) {
    final tries = r.triesBeforeWait == 1 ? '1 more try' : '${r.triesBeforeWait} more tries';
    return 'That PIN is not right. $tries before a wait.';
  }
  return 'That PIN is not right. Try again.';
}

/// "Try again in 0:45." or "Try again in 14:59." Rounded up so it never reads 0:00.
String waitMessage(Duration wait) {
  final seconds = (wait.inMilliseconds / 1000).ceil();
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return 'Too many wrong tries. Try again in $m:$s.';
}

/// Runs a once-a-second countdown while a wait after wrong tries lasts.
mixin PinWaitCountdown<T extends StatefulWidget> on State<T> {
  Timer? _ticker;
  DateTime? _waitUntil;

  /// Time left, or null when there is no wait.
  Duration? get waitLeft {
    final until = _waitUntil;
    if (until == null) return null;
    final left = until.difference(clock.now());
    return left > Duration.zero ? left : null;
  }

  void startWait(Duration wait) {
    _ticker?.cancel();
    _waitUntil = clock.now().add(wait);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (waitLeft == null) {
        _ticker?.cancel();
        _waitUntil = null;
        onWaitOver();
      }
      setState(() {});
    });
    setState(() {});
  }

  /// Called once when the wait has passed.
  void onWaitOver();

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// The lock screen (Lock.html). It sits over the app in the app builder, not on a route.
///
/// With "Fingerprint or face" chosen and available it asks for one as it opens; the PIN
/// works either way. "Forgot your PIN?" can only delete everything, since there is no account
/// to reset it through (undrawn, design check).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onWiped});

  /// Called after "Forgot your PIN?" has deleted everything, to open the app somewhere useful.
  final VoidCallback onWiped;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with PinWaitCountdown {
  String _message = lockHelp;
  bool _problem = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWait());
  }

  Future<void> _loadWait() async {
    Duration wait;
    try {
      wait = await ref.read(pinStoreProvider).currentWait();
    } on Object {
      return;
    }
    if (mounted && wait > Duration.zero) startWait(wait);
  }

  @override
  void onWaitOver() {
    _message = lockHelp;
    _problem = false;
  }

  bool get _biometricChosen {
    final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
    return PrivacyKeys.unlockWith.decode(s[PrivacyKeys.unlockWith.name]) == UnlockMethod.biometric;
  }

  Future<void> _submit(String pin) async {
    PinCheck result;
    try {
      result = await ref.read(lockControllerProvider.notifier).unlockWithPin(pin);
    } on Object {
      if (mounted) _show('Your PIN could not be checked. Try again.');
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        return;
      case PinRejected(:final wait) when wait > Duration.zero:
        _show(wrongPinMessage(result));
        startWait(wait);
      case PinRejected():
        _show(wrongPinMessage(result));
      case PinMustWait(:final wait):
        _show(waitMessage(wait));
        startWait(wait);
    }
  }

  void _show(String message) => setState(() {
    _message = message;
    _problem = true;
  });

  Future<void> _biometric() async {
    final result = await ref.read(lockControllerProvider.notifier).unlockWithBiometrics();
    if (!mounted) return;
    switch (result) {
      case BiometricResult.passed:
        return;
      case BiometricResult.failed:
        // The phone's prompt already said why; closing it leaves the PIN, as drawn.
        return;
      case BiometricResult.unavailable:
        _show('Fingerprint or face is not available right now. Enter your PIN.');
    }
  }

  Future<void> _forgot() async {
    final c = context.colors;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete everything to get back in?'),
        content: const Text(
          'Akatabo has no account, so a forgotten PIN cannot be reset. The only way back in is '
          'to delete everything on this phone: every entry, account, category, budget and '
          'setting, and the PIN.\n\nYou can then restore a backup file, if you saved one. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.moneyOut),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(lockControllerProvider.notifier).forgetEverything();
    } on Object {
      if (mounted) _show('Nothing was deleted. Try again.');
      return;
    }
    widget.onWiped();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(biometricsAvailableProvider).value ?? false;
    final offerBiometric = available && _biometricChosen;
    if (offerBiometric && !_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && waitLeft == null) unawaited(_biometric());
      });
    }
    final left = waitLeft;
    return PinPanel(
      title: 'Enter your PIN',
      message: left != null ? waitMessage(left) : _message,
      messageIsProblem: left != null || _problem,
      enabled: left == null,
      onSubmit: _submit,
      onBiometric: offerBiometric ? _biometric : null,
      footer: PinTextButton(label: 'Forgot your PIN?', onTap: _forgot),
    );
  }
}
