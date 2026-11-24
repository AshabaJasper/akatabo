import 'dart:math' show min;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';

/// A small key-value store kept outside the database. The app uses the phone's secure
/// storage (keystore-wrapped on Android); tests use a map.
abstract interface class SecureValues {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [SecureValues] on `flutter_secure_storage`.
class DeviceSecureValues implements SecureValues {
  DeviceSecureValues([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Milliseconds since the phone started, which changing the date and time does not move.
/// Null where it cannot be read.
typedef SinceBoot = Future<int?> Function();

/// Android's `SystemClock.elapsedRealtime()` through the `akatabo/privacy` channel.
Future<int?> channelSinceBoot() async {
  try {
    return await const MethodChannel('akatabo/privacy').invokeMethod<int>('elapsedRealtime');
  } on Object {
    return null;
  }
}

final secureValuesProvider = Provider<SecureValues>((ref) => DeviceSecureValues());
final pinHasherProvider = Provider<PinHasher>((ref) => PinHasher());
final sinceBootProvider = Provider<SinceBoot>((ref) => channelSinceBoot);
final pinStoreProvider = Provider<PinStore>(
  (ref) => PinStore(
    ref.watch(secureValuesProvider),
    ref.watch(pinHasherProvider),
    sinceBoot: ref.watch(sinceBootProvider),
  ),
);

/// The answer to one PIN try.
sealed class PinCheck {
  const PinCheck();
}

/// The PIN was right. Wrong tries are forgotten.
final class PinAccepted extends PinCheck {
  const PinAccepted();
}

/// The PIN was wrong. [wait] is how long before the next try is allowed (zero when there is
/// no wait yet); [triesBeforeWait] counts the free tries left before waits begin.
final class PinRejected extends PinCheck {
  const PinRejected({required this.wait, required this.triesBeforeWait});
  final Duration wait;
  final int triesBeforeWait;
}

/// Too many wrong tries: nothing is checked until [wait] has passed.
final class PinMustWait extends PinCheck {
  const PinMustWait(this.wait);
  final Duration wait;
}

/// The PIN hash and the count of wrong tries, both in secure storage, so closing the app
/// does not reset a wait.
///
/// A wait is timed by two clocks: the phone's date and time, and the time since the phone
/// started. Only the smaller of the two counts, so moving the date forward does not end a
/// wait early, and moving it back starts the wait again from the beginning.
class PinStore {
  PinStore(this._values, this._hasher, {SinceBoot? sinceBoot})
    : _sinceBoot = sinceBoot ?? _unknownBoot;

  final SecureValues _values;
  final PinHasher _hasher;
  final SinceBoot _sinceBoot;

  static Future<int?> _unknownBoot() async => null;

  static const _hashKey = 'akatabo.pin.hash';
  static const _failuresKey = 'akatabo.pin.failures';

  /// The date and time of the last wrong try, in milliseconds since the epoch.
  static const _failedAtKey = 'akatabo.pin.failedAt';

  /// Milliseconds since the phone started, at the last wrong try.
  static const _failedAtBootKey = 'akatabo.pin.failedAtBoot';

  /// Wrong tries allowed before the first wait.
  static const freeTries = 4;

  /// The wait after the [failures]th wrong try in a row: none for the first four, then
  /// 30 seconds, 1 minute, 5 minutes, 15 minutes, and an hour from the ninth on.
  static Duration waitAfter(int failures) {
    if (failures <= freeTries) return Duration.zero;
    return switch (failures - freeTries) {
      1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 1),
      3 => const Duration(minutes: 5),
      4 => const Duration(minutes: 15),
      _ => const Duration(hours: 1),
    };
  }

  Future<bool> hasPin() async => (await _values.read(_hashKey)) != null;

  /// Wrong tries in a row, for the App lock rows. Zero after a right PIN.
  Future<int> wrongTries() async => int.tryParse(await _values.read(_failuresKey) ?? '') ?? 0;

  /// Stores a new PIN in place of any old one and forgets wrong tries.
  Future<void> setPin(String pin) async {
    final record = await _hasher.hash(pin);
    await _values.write(_hashKey, record);
    await _resetTries();
  }

  /// Removes the PIN and the wrong-try count.
  Future<void> clear() async {
    await _values.delete(_hashKey);
    await _resetTries();
  }

  /// How long before a PIN may be tried again. Zero when it can be tried now.
  Future<Duration> currentWait() async {
    final failures = int.tryParse(await _values.read(_failuresKey) ?? '') ?? 0;
    final wait = waitAfter(failures);
    if (wait == Duration.zero) return Duration.zero;
    final failedAt = int.tryParse(await _values.read(_failedAtKey) ?? '') ?? 0;
    final failedAtBoot = int.tryParse(await _values.read(_failedAtBootKey) ?? '');
    final now = clock.now().millisecondsSinceEpoch;
    final boot = await _safeSinceBoot();
    if (now < failedAt) {
      // The date was moved back: the wait starts again from now, never longer than itself.
      await _markFailure(now, boot);
      return wait;
    }
    var elapsed = now - failedAt;
    // Same start-up as the wrong try: the time since start-up cannot be moved by hand.
    if (failedAtBoot != null && boot != null && boot >= failedAtBoot) {
      elapsed = min(elapsed, boot - failedAtBoot);
    }
    final left = wait - Duration(milliseconds: elapsed);
    return left > Duration.zero ? left : Duration.zero;
  }

  Future<int?> _safeSinceBoot() async {
    try {
      return await _sinceBoot();
    } on Object {
      return null;
    }
  }

  Future<void> _markFailure(int now, int? boot) async {
    await _values.write(_failedAtKey, '$now');
    if (boot == null) {
      await _values.delete(_failedAtBootKey);
    } else {
      await _values.write(_failedAtBootKey, '$boot');
    }
  }

  /// Checks [pin]. A wrong one counts towards the waits, saved before the answer returns.
  Future<PinCheck> check(String pin) async {
    final wait = await currentWait();
    if (wait > Duration.zero) return PinMustWait(wait);
    final record = await _values.read(_hashKey);
    if (record != null && await _hasher.verify(pin, record)) {
      await _resetTries();
      return const PinAccepted();
    }
    final failures = (int.tryParse(await _values.read(_failuresKey) ?? '') ?? 0) + 1;
    final next = waitAfter(failures);
    await _values.write(_failuresKey, '$failures');
    await _markFailure(clock.now().millisecondsSinceEpoch, await _safeSinceBoot());
    return PinRejected(
      wait: next,
      triesBeforeWait: failures >= freeTries ? 0 : freeTries - failures,
    );
  }

  Future<void> _resetTries() async {
    await _values.delete(_failuresKey);
    await _values.delete(_failedAtKey);
    await _values.delete(_failedAtBootKey);
  }
}
