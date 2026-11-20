import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// How a backup password became a key: the algorithm, its cost settings and the salt.
/// Written into the readable header of a protected backup, so the file can be opened on any
/// phone, and so it says which algorithm was used.
class KdfParams {
  const KdfParams({
    required this.name,
    required this.iterations,
    required this.salt,
    this.memoryKiB = 0,
    this.parallelism = 1,
    this.millis,
    this.fellBack = false,
  });

  /// Argon2id with the OWASP minimum: 19 MiB, two passes, one lane.
  factory KdfParams.argon2id(List<int> salt) =>
      KdfParams(name: argon2idName, iterations: 2, memoryKiB: 19456, salt: salt);

  /// PBKDF2-HMAC-SHA256 with 310,000 rounds (OWASP's 2021 figure). Used only when Argon2id
  /// takes more than about two seconds on this phone.
  factory KdfParams.pbkdf2(List<int> salt) =>
      KdfParams(name: pbkdf2Name, iterations: 310000, salt: salt);

  static const argon2idName = 'argon2id';
  static const pbkdf2Name = 'pbkdf2-sha256';

  /// The most work a header may ask for: a little over what Akatabo writes, so a future
  /// stronger setting still opens, but a hostile file cannot make the phone run out of
  /// memory or check a password for minutes.
  static const maxArgonMemoryKiB = 65536;
  static const maxArgonIterations = 4;
  static const maxArgonLanes = 4;
  static const maxPbkdf2Iterations = 1000000;

  final String name;
  final int iterations;
  final int memoryKiB;
  final int parallelism;
  final List<int> salt;

  /// How long the key took to make when the backup was saved, for the record.
  final int? millis;

  /// True when Argon2id was too slow and PBKDF2 was used instead.
  final bool fellBack;

  KdfParams copyWith({int? millis, bool? fellBack}) => KdfParams(
    name: name,
    iterations: iterations,
    memoryKiB: memoryKiB,
    parallelism: parallelism,
    salt: salt,
    millis: millis ?? this.millis,
    fellBack: fellBack ?? this.fellBack,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'iterations': iterations,
    if (name == argon2idName) 'memoryKiB': memoryKiB,
    if (name == argon2idName) 'parallelism': parallelism,
    'salt': base64Encode(salt),
    'millis': ?millis,
    'fellBackFromArgon2id': fellBack,
  };

  /// Reads the header's description. Null when it is missing, unknown, or asks for so much
  /// work or memory that it cannot have come from Akatabo (a damaged or hostile file).
  static KdfParams? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final iterations = json['iterations'];
    final saltText = json['salt'];
    if (iterations is! int || iterations < 1 || saltText is! String) return null;
    final List<int> salt;
    try {
      salt = base64Decode(saltText);
    } on FormatException {
      return null;
    }
    if (salt.length < 8) return null;
    final fellBack = json['fellBackFromArgon2id'] == true;
    final millis = json['millis'] is int ? json['millis'] as int : null;
    if (name == argon2idName) {
      final memory = json['memoryKiB'];
      final lanes = json['parallelism'];
      if (memory is! int || lanes is! int) return null;
      if (lanes < 1 || lanes > maxArgonLanes) return null;
      if (memory < 8 * lanes || memory > maxArgonMemoryKiB) return null;
      if (iterations > maxArgonIterations) return null;
      return KdfParams(
        name: name as String,
        iterations: iterations,
        memoryKiB: memory,
        parallelism: lanes,
        salt: salt,
        millis: millis,
        fellBack: fellBack,
      );
    }
    if (name == pbkdf2Name) {
      if (iterations > maxPbkdf2Iterations) return null;
      return KdfParams(
        name: name as String,
        iterations: iterations,
        salt: salt,
        millis: millis,
        fellBack: fellBack,
      );
    }
    return null;
  }
}

/// Makes the 256-bit key straight away, on the calling isolate.
Future<List<int>> deriveKeyNow(String password, KdfParams p) async {
  final KdfAlgorithm algorithm = p.name == KdfParams.argon2idName
      ? DartArgon2id(
          parallelism: p.parallelism,
          memory: p.memoryKiB,
          iterations: p.iterations,
          hashLength: 32,
        )
      : DartPbkdf2(macAlgorithm: Hmac.sha256(), iterations: p.iterations, bits: 256);
  final key = await algorithm.deriveKeyFromPassword(password: password, nonce: p.salt);
  return key.extractBytes();
}

/// Runs [deriveKeyNow] on its own isolate and gives up after [deadline], stopping that
/// isolate so it does not keep the phone busy. Null when the deadline passed.
Future<List<int>?> deriveInIsolateWithin(String password, KdfParams p, Duration deadline) async {
  final port = ReceivePort();
  final isolate = await Isolate.spawn(_isolateEntry, (port.sendPort, password, p.toJson()));
  try {
    final reply = await port.first.timeout(deadline);
    if (reply is List<int>) return reply;
    throw StateError('The key could not be made: $reply');
  } on TimeoutException {
    return null;
  } finally {
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }
}

Future<void> _isolateEntry((SendPort, String, Map<String, Object?>) message) async {
  final (reply, password, json) = message;
  try {
    reply.send(await deriveKeyNow(password, KdfParams.fromJson(json)!));
  } catch (error) {
    reply.send('$error');
  }
}

/// A key and how it was made.
typedef DerivedKey = ({List<int> key, KdfParams params});

typedef TryWithin = Future<List<int>?> Function(String password, KdfParams p, Duration deadline);
typedef DeriveFully = Future<List<int>> Function(String password, KdfParams p);

/// Turns a backup password into a key, off the screen's isolate.
///
/// A new backup tries Argon2id first and times it. When it is not done within [budget]
/// (about two seconds), it is stopped and PBKDF2 is used instead, and the header records
/// that. The slow result is remembered for as long as the app runs, so the person waits
/// for the slow attempt only once.
class KeyDeriver {
  KeyDeriver({
    this.budget = const Duration(seconds: 2),
    TryWithin? tryWithin,
    DeriveFully? deriveFully,
    Random? random,
  }) : _tryWithin = tryWithin ?? deriveInIsolateWithin,
       _deriveFully = deriveFully ?? _isolateRun,
       _random = random ?? Random.secure();

  final Duration budget;
  final TryWithin _tryWithin;
  final DeriveFully _deriveFully;
  final Random _random;
  bool _argonTooSlow = false;

  static Future<List<int>> _isolateRun(String password, KdfParams p) =>
      Isolate.run(() => deriveKeyNow(password, p));

  List<int> _salt() => List<int>.generate(16, (_) => _random.nextInt(256));

  /// A key for a new backup, with a fresh salt.
  Future<DerivedKey> forNewBackup(String password) async {
    final watch = Stopwatch()..start();
    if (!_argonTooSlow) {
      final params = KdfParams.argon2id(_salt());
      final key = await _tryWithin(password, params, budget);
      if (key != null) {
        return (key: key, params: params.copyWith(millis: watch.elapsedMilliseconds));
      }
      _argonTooSlow = true;
    }
    watch.reset();
    final params = KdfParams.pbkdf2(_salt());
    final key = await _deriveFully(password, params);
    return (key: key, params: params.copyWith(millis: watch.elapsedMilliseconds, fellBack: true));
  }

  /// The key for an existing backup, made the way its header says.
  Future<List<int>> forExisting(String password, KdfParams params) =>
      _deriveFully(password, params);
}
