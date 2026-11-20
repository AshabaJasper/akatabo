import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// The outcome of asking for a fingerprint or face.
enum BiometricResult {
  /// The person was recognised.
  passed,

  /// They cancelled or were not recognised; the PIN is there instead.
  failed,

  /// The phone cannot ask right now (no fingerprint or face set up, too many tries, or the
  /// sensor is unavailable).
  unavailable,
}

/// Fingerprint or face unlock. Screens use this interface; tests use a fake.
abstract interface class Biometrics {
  /// Whether the phone has a fingerprint or face set up that Akatabo could ask for.
  Future<bool> isAvailable();

  /// Asks for a fingerprint or face, saying [reason] in the phone's own prompt.
  Future<BiometricResult> authenticate(String reason);
}

final biometricsProvider = Provider<Biometrics>((ref) => LocalAuthBiometrics());

/// Whether "Fingerprint or face" can be offered, read once per app run.
final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(biometricsProvider).isAvailable();
  } on Object {
    return false;
  }
});

/// [Biometrics] on `local_auth` 3. Biometric only: the fallback is Akatabo's own PIN, not
/// the phone's screen lock.
class LocalAuthBiometrics implements Biometrics {
  LocalAuthBiometrics([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    if (!await _auth.canCheckBiometrics) return false;
    return (await _auth.getAvailableBiometrics()).isNotEmpty;
  }

  @override
  Future<BiometricResult> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason, biometricOnly: true);
      return ok ? BiometricResult.passed : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback => BiometricResult.failed,
        _ => BiometricResult.unavailable,
      };
    } on Object {
      return BiometricResult.unavailable;
    }
  }
}
