import 'package:akatabo/services/security/biometrics.dart';
import 'package:akatabo/services/security/pin_hasher.dart';
import 'package:akatabo/services/security/pin_store.dart';
import 'package:akatabo/services/security/privacy_window.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Secure storage as a map. Survives a "restart" when the same instance is reused.
class MapSecureValues implements SecureValues {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.available = true, this.result = BiometricResult.passed});
  bool available;
  BiometricResult result;
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricResult> authenticate(String reason) async {
    asked++;
    return result;
  }
}

class FakePrivacyWindow implements PrivacyWindow {
  final calls = <bool>[];
  @override
  Future<void> setHiddenInRecents(bool hidden) async => calls.add(hidden);
}

/// A hasher with few rounds, so tests stay fast. The scheme is the same.
PinHasher fastHasher() => PinHasher(iterations: 10, inBackground: false);

/// Overrides for every security plugin.
List<Override> securityOverrides({
  required MapSecureValues values,
  FakeBiometrics? biometrics,
  FakePrivacyWindow? window,
}) => [
  secureValuesProvider.overrideWithValue(values),
  pinHasherProvider.overrideWithValue(fastHasher()),
  sinceBootProvider.overrideWithValue(() async => null),
  biometricsProvider.overrideWithValue(biometrics ?? FakeBiometrics(available: false)),
  privacyWindowProvider.overrideWithValue(window ?? FakePrivacyWindow()),
];

/// A store holding [pin], as if it had been set earlier.
Future<MapSecureValues> valuesWithPin(String pin) async {
  final values = MapSecureValues();
  await PinStore(values, fastHasher()).setPin(pin);
  return values;
}
