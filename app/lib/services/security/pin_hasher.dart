import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Turns a PIN into a stored record and checks a PIN against one. The PIN itself is never
/// kept: only a PBKDF2-HMAC-SHA256 hash with a random 16-byte salt.
///
/// The record is `pbkdf2-sha256$<iterations>$<salt>$<hash>` (base64), so the iteration
/// count can change later without breaking PINs already set.
///
/// A four-digit PIN has 10,000 possible values, so no hash makes it strong on its own. The
/// hash keeps the PIN from being read back in plain text; the real protection is that the
/// record sits in the phone's keystore-backed secure storage and that wrong tries are slowed
/// down (see `PinStore`). The database is not encrypted by the PIN.
class PinHasher {
  PinHasher({this.iterations = defaultIterations, this.inBackground = true, Random? random})
    : _random = random ?? Random.secure();

  /// Enough to make each guess cost real time on a phone without a long wait to unlock.
  static const defaultIterations = 60000;
  static const _scheme = 'pbkdf2-sha256';
  static const _saltBytes = 16;
  static const _hashBits = 256;

  final int iterations;

  /// Works out the hash on a background isolate, so the keypad never freezes while it runs
  /// (about a quarter of a second on a desktop). Tests with few rounds turn this off.
  final bool inBackground;
  final Random _random;

  /// A new record for [pin] with a fresh salt.
  Future<String> hash(String pin) async {
    final salt = List<int>.generate(_saltBytes, (_) => _random.nextInt(256));
    final derived = await _derive(pin, salt, iterations);
    return [_scheme, '$iterations', base64Encode(salt), base64Encode(derived)].join(r'$');
  }

  /// Whether [pin] matches [record]. A damaged record never matches.
  Future<bool> verify(String pin, String record) async {
    final parts = record.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return false;
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = await _derive(pin, salt, rounds);
    return _sameBytes(actual, expected);
  }

  Future<List<int>> _derive(String pin, List<int> salt, int rounds) =>
      _deriveOn(inBackground, pin, salt, rounds);

  /// Static, so the closure sent to the isolate holds only the PIN, salt and rounds.
  static Future<List<int>> _deriveOn(bool background, String pin, List<int> salt, int rounds) =>
      background
      ? Isolate.run(() => _deriveHere(pin, salt, rounds))
      : _deriveHere(pin, salt, rounds);

  static Future<List<int>> _deriveHere(String pin, List<int> salt, int rounds) async {
    final kdf = Pbkdf2.hmacSha256(iterations: rounds, bits: _hashBits);
    final key = await kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  /// Compares every byte whatever the first difference, so timing says nothing.
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
