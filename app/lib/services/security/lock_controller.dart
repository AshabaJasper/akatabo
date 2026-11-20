import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../data_reset.dart';
import 'biometrics.dart';
import 'hidden_amounts.dart';
import 'pin_store.dart';
import 'privacy_settings.dart';

/// Where the app lock stands.
enum LockStatus {
  /// Start-up: not yet known whether the lock is on. Nothing of the app is shown.
  checking,

  /// The lock screen covers the app.
  locked,

  /// The app is open.
  unlocked,
}

final lockControllerProvider = NotifierProvider<LockController, LockStatus>(LockController.new);

/// Whether a PIN is stored, for the Privacy and security rows. Invalidated after each change.
final pinIsSetProvider = FutureProvider<bool>((ref) => ref.watch(pinStoreProvider).hasPin());

/// Decides when the app is locked, and turns the lock on and off.
///
/// The lock applies only when "Lock the app" is on in settings and a PIN hash is stored.
/// Needing both means "Delete everything" (which clears the settings) switches the lock off,
/// and a setting with no PIN behind it can never shut the person out.
class LockController extends Notifier<LockStatus> {
  bool _decided = false;
  DateTime? _awayAt;
  int _keepUnlocked = 0;

  @override
  LockStatus build() {
    final now = ref.read(storedSettingsProvider);
    if (now.hasValue) {
      final on = _read(now.requireValue, PrivacyKeys.lockOn);
      _decided = true;
      if (!on) return LockStatus.unlocked;
      unawaited(Future.microtask(_decideFromPin));
      return LockStatus.checking;
    }
    ref.listen(storedSettingsProvider, (_, next) {
      if (_decided || next.isLoading) return;
      _decided = true;
      if (next.hasValue && !_read(next.requireValue, PrivacyKeys.lockOn)) {
        state = LockStatus.unlocked;
      } else {
        // Settings that cannot be read fall back to the PIN: locked if one is stored.
        unawaited(_decideFromPin());
      }
    });
    return LockStatus.checking;
  }

  static T _read<T>(Map<String, String> s, SettingKey<T> key) => key.decode(s[key.name]);

  Map<String, String> get _settings =>
      ref.read(storedSettingsProvider).value ?? const <String, String>{};

  bool get _lockOn => _read(_settings, PrivacyKeys.lockOn);

  Future<void> _decideFromPin() async {
    bool hasPin;
    try {
      hasPin = await ref.read(pinStoreProvider).hasPin();
    } on Object catch (error, stack) {
      // Secure storage could not be read: stay locked. "Forgot your PIN?" still works.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo lock'),
      );
      hasPin = true;
    }
    state = hasPin ? LockStatus.locked : LockStatus.unlocked;
  }

  /// The app went out of sight. Hidden figures are dotted again either way.
  void wentAway() {
    ref.read(amountsRevealedProvider.notifier).hideAgain();
    if (_keepUnlocked > 0 || state != LockStatus.unlocked || !_lockOn) return;
    _awayAt = clock.now();
    if (_read(_settings, PrivacyKeys.lockAfter) == LockAfter.rightAway) state = LockStatus.locked;
  }

  /// The app is in sight again: lock if it was away for at least the chosen time.
  void cameBack() {
    final since = _awayAt;
    _awayAt = null;
    if (since == null || state != LockStatus.unlocked || !_lockOn) return;
    final away = clock.now().difference(since);
    // A date moved back while away reads as negative time: lock rather than trust it.
    if (away.isNegative || away >= _read(_settings, PrivacyKeys.lockAfter).away) {
      state = LockStatus.locked;
    }
  }

  /// Runs [action] without locking when the app is briefly hidden by it, such as the
  /// phone's fingerprint prompt or a file picker.
  Future<T> keepUnlockedWhile<T>(Future<T> Function() action) async {
    _keepUnlocked++;
    try {
      return await action();
    } finally {
      _keepUnlocked--;
      _awayAt = null;
    }
  }

  /// Tries [pin] on the lock screen.
  Future<PinCheck> unlockWithPin(String pin) async {
    final result = await ref.read(pinStoreProvider).check(pin);
    if (result is PinAccepted) state = LockStatus.unlocked;
    return result;
  }

  /// Asks for a fingerprint or face on the lock screen.
  Future<BiometricResult> unlockWithBiometrics() async {
    final result = await keepUnlockedWhile(
      () => ref.read(biometricsProvider).authenticate('Unlock Akatabo'),
    );
    if (result == BiometricResult.passed) state = LockStatus.unlocked;
    return result;
  }

  /// Stores [pin] and switches the lock on. The PIN is stored first, so the setting never
  /// says "on" without a PIN behind it.
  Future<void> turnOn(String pin) async {
    final pins = ref.read(pinStoreProvider);
    await pins.setPin(pin);
    try {
      await ref.read(settingsRepositoryProvider).write(PrivacyKeys.lockOn, true);
    } on Object {
      await pins.clear();
      rethrow;
    } finally {
      ref.invalidate(pinIsSetProvider);
    }
  }

  /// Replaces the PIN. The caller has already checked the current one.
  Future<void> changePin(String pin) async {
    await ref.read(pinStoreProvider).setPin(pin);
    ref.invalidate(pinIsSetProvider);
  }

  /// Switches the lock off and removes the PIN. The setting goes first: a PIN left behind
  /// without the setting does nothing and is replaced when a new one is set.
  Future<void> turnOff() async {
    await ref.read(settingsRepositoryProvider).write(PrivacyKeys.lockOn, false);
    try {
      await ref.read(pinStoreProvider).clear();
    } finally {
      ref.invalidate(pinIsSetProvider);
    }
  }

  /// "Forgot your PIN?": deletes every entry and setting on the phone, removes the PIN and
  /// opens the app. Nothing is deleted if the database step fails.
  Future<void> forgetEverything() async {
    await deleteEverything(ref.read(appDatabaseProvider));
    try {
      await ref.read(pinStoreProvider).clear();
    } on Object catch (error, stack) {
      // The lock setting is already gone with the other settings, so the app no longer locks;
      // a PIN left behind is replaced when a new one is set.
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo lock'),
      );
    }
    ref.invalidate(pinIsSetProvider);
    ref.read(amountsRevealedProvider.notifier).hideAgain();
    _awayAt = null;
    state = LockStatus.unlocked;
  }
}
