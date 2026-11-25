import 'dart:async';

import 'package:akatabo/data/providers.dart';
import 'package:akatabo/services/security/biometrics.dart';
import 'package:akatabo/services/security/hidden_amounts.dart';
import 'package:akatabo/services/security/lock_controller.dart';
import 'package:akatabo/services/security/pin_store.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_security.dart';

final _on = {PrivacyKeys.lockOn.name: '1'};

Future<ProviderContainer> _container(
  Map<String, String> settings,
  MapSecureValues values, {
  FakeBiometrics? biometrics,
}) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
      ...securityOverrides(values: values, biometrics: biometrics),
    ],
  );
  addTearDown(container.dispose);
  container.listen(storedSettingsProvider, (_, _) {});
  container.listen(lockControllerProvider, (_, _) {});
  await container.read(storedSettingsProvider.future);
  // Let the start-up decision (which reads secure storage) finish.
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return container;
}

void main() {
  final start = DateTime(2026, 11, 19, 9, 14);

  // The phone case: the stored settings cannot be read (here, the database is a newer
  // version than this build), and that error is already there when the lock starts. The
  // lock must still decide from the PIN, not wait forever on "checking" with a blank screen.
  Future<ProviderContainer> unreadable(MapSecureValues values) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith(
          (ref) => Stream<Map<String, String>>.error(StateError('database is a newer version')),
        ),
        ...securityOverrides(values: values),
      ],
    );
    addTearDown(container.dispose);
    container.listen(storedSettingsProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // Only now does the lock start, so it finds the error already in place.
    container.listen(lockControllerProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container;
  }

  test('settings that cannot be read: the lock falls back to the PIN and locks', () async {
    final c = await unreadable(await valuesWithPin('2580'));
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('settings that cannot be read, and no PIN: the app opens, not stuck', () async {
    final c = await unreadable(MapSecureValues());
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('locks on start when the lock is on and a PIN is stored', () async {
    final c = await _container(_on, await valuesWithPin('2580'));
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('stays open when the lock is off, even with a PIN left behind', () async {
    final c = await _container(const {}, await valuesWithPin('2580'));
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('a lock setting with no PIN behind it never shuts the person out', () async {
    final c = await _container(_on, MapSecureValues());
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('unlocks with the right PIN only', () async {
    final c = await _container(_on, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    expect(await lock.unlockWithPin('1111'), isA<PinRejected>());
    expect(c.read(lockControllerProvider), LockStatus.locked);
    expect(await lock.unlockWithPin('2580'), isA<PinAccepted>());
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('locks again after the chosen time away, not before', () async {
    final c = await _container(_on, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.unlockWithPin('2580');

    withClock(Clock.fixed(start), lock.wentAway);
    withClock(Clock.fixed(start.add(const Duration(seconds: 59))), lock.cameBack);
    expect(c.read(lockControllerProvider), LockStatus.unlocked, reason: 'under a minute');

    withClock(Clock.fixed(start), lock.wentAway);
    withClock(Clock.fixed(start.add(const Duration(minutes: 1))), lock.cameBack);
    expect(c.read(lockControllerProvider), LockStatus.locked, reason: 'a minute away');
  });

  test('a date moved back while away still locks', () async {
    final c = await _container(_on, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.unlockWithPin('2580');
    withClock(Clock.fixed(start), lock.wentAway);
    withClock(Clock.fixed(start.subtract(const Duration(hours: 1))), lock.cameBack);
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('switching Hide amounts off and on dots the figures again', () async {
    final settings = StreamController<Map<String, String>>();
    addTearDown(settings.close);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [storedSettingsProvider.overrideWith((ref) => settings.stream)],
    );
    addTearDown(c.dispose);
    c.listen(amountsHiddenProvider, (_, _) {});
    Future<void> send(String v) async {
      settings.add({PrivacyKeys.hideAmounts.name: v});
      await Future<void>.delayed(Duration.zero);
    }

    await send('1');
    expect(c.read(amountsHiddenProvider), isTrue);
    c.read(amountsRevealedProvider.notifier).reveal();
    expect(c.read(amountsHiddenProvider), isFalse);
    await send('0');
    await send('1');
    expect(c.read(amountsHiddenProvider), isTrue);
  });

  test('"Right away" locks as soon as the app is hidden', () async {
    final settings = {..._on, PrivacyKeys.lockAfter.name: LockAfter.rightAway.name};
    final c = await _container(settings, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.unlockWithPin('2580');
    lock.wentAway();
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('the fingerprint prompt hiding the app does not lock it', () async {
    final settings = {..._on, PrivacyKeys.lockAfter.name: LockAfter.rightAway.name};
    final c = await _container(settings, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.unlockWithPin('2580');
    await lock.keepUnlockedWhile(() async {
      lock
        ..wentAway()
        ..cameBack();
    });
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('a failed fingerprint leaves it locked; a passed one opens it', () async {
    final bio = FakeBiometrics(result: BiometricResult.failed);
    final c = await _container(_on, await valuesWithPin('2580'), biometrics: bio);
    final lock = c.read(lockControllerProvider.notifier);
    expect(await lock.unlockWithBiometrics(), BiometricResult.failed);
    expect(c.read(lockControllerProvider), LockStatus.locked);
    bio.result = BiometricResult.passed;
    expect(await lock.unlockWithBiometrics(), BiometricResult.passed);
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });

  test('going away hides revealed amounts again', () async {
    final c = await _container(const {}, MapSecureValues());
    c.read(amountsRevealedProvider.notifier).reveal();
    c.read(lockControllerProvider.notifier).wentAway();
    expect(c.read(amountsRevealedProvider), isFalse);
  });

  test('Lock now covers an open app at once, when the lock is on', () async {
    final c = await _container(_on, await valuesWithPin('2580'));
    final lock = c.read(lockControllerProvider.notifier);
    await lock.unlockWithPin('2580');
    expect(c.read(lockControllerProvider), LockStatus.unlocked);

    lock.lockNow();
    expect(c.read(lockControllerProvider), LockStatus.locked);
  });

  test('Lock now does nothing while the lock is off', () async {
    final c = await _container(const {}, await valuesWithPin('2580'));
    c.read(lockControllerProvider.notifier).lockNow();
    expect(c.read(lockControllerProvider), LockStatus.unlocked);
  });
}
