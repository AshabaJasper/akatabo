import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'key_derivation.dart';

/// The `.akatabo` backup file. Plain Dart, no Flutter, so it is tested on its own.
///
/// Layout, top to bottom:
///
/// 1. The line `AKATABO-BACKUP`.
/// 2. One line of JSON: the readable header. Format and its version, the database schema
///    version, the app version, the number of rows in each table, the first and last entry
///    days, whether a password protects it and, when it does, how the key is made (the
///    algorithm, its settings and the salt) and the nonce. Anyone can read this line, so it
///    holds no amounts, names or descriptions.
/// 3. The line `sha256:` and the SHA-256 of the header line and the stored payload, so a
///    damaged file is told apart from a wrong password.
/// 4. The payload: every table as JSON, gzipped, then sealed with AES-256-GCM when a
///    password is set. The header line's bytes are the associated data, so a changed header
///    is caught too.
///
/// The PIN and anything in secure storage are never part of the tables, so never in a file.
abstract final class BackupFormat {
  static const magic = 'AKATABO-BACKUP';
  static const name = 'akatabo-backup';

  /// The layout version this code writes. A file with a higher one is refused before any
  /// decrypting, as "from a newer version of Akatabo".
  static const version = 1;
  static const extension = 'akatabo';

  /// Every table in the database, by its name in the file, parents before children.
  static const tables = [
    'accounts',
    'categories',
    'regularPayments',
    'transactions',
    'settings',
    'forecastSnapshots',
  ];

  /// The header line may not be longer than this; anything longer is not an Akatabo file.
  static const maxHeaderBytes = 64 * 1024;
}

/// Rows of every table as JSON maps, keyed by [BackupFormat.tables] names.
typedef BackupTables = Map<String, List<Map<String, Object?>>>;

/// Why a backup file could not be opened. Each has its own words on the Restore screen.
enum BackupProblem {
  /// It does not start like an Akatabo backup.
  notAkatabo,

  /// It starts like one but is cut short, changed or unreadable.
  damaged,

  /// It was saved by a newer Akatabo, with a newer layout or database.
  newerVersion,

  /// It is protected and no password was given.
  passwordNeeded,

  /// The password does not open it.
  wrongPassword,
}

class BackupException implements Exception {
  const BackupException(this.problem, {this.appVersion});
  final BackupProblem problem;

  /// The app version written in the file, when it could be read (for "newer version").
  final String? appVersion;

  @override
  String toString() => 'BackupException(${problem.name})';
}

/// The readable header line.
class BackupHeader {
  const BackupHeader({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.counts,
    required this.firstDay,
    required this.lastDay,
    this.kdf,
    this.nonce,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;

  /// Rows in each table.
  final Map<String, int> counts;

  /// The first and last entry days (yyyymmdd), or null with no entries.
  final int? firstDay;
  final int? lastDay;

  /// How the key is made. Null when there is no password.
  final KdfParams? kdf;
  final List<int>? nonce;

  bool get isProtected => kdf != null;

  Map<String, Object?> toJson() => {
    'format': BackupFormat.name,
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toIso8601String(),
    'counts': counts,
    'firstDay': firstDay,
    'lastDay': lastDay,
    'protected': isProtected,
    if (kdf != null) 'kdf': kdf!.toJson(),
    if (nonce != null) 'nonce': base64Encode(nonce!),
  };
}

/// Encodes and decodes `.akatabo` files.
class BackupCodec {
  BackupCodec({
    required this.schemaVersion,
    KeyDeriver? keys,
    this.maxUnzippedBytes = defaultMaxUnzippedBytes,
  }) : keys = keys ?? KeyDeriver();

  /// The database schema this app reads. A file from a higher one is refused.
  final int schemaVersion;
  final KeyDeriver keys;

  /// The most the payload may unzip to. Years of entries come to a few megabytes; a file
  /// that unzips past this is refused as damaged rather than filling the phone's memory.
  final int maxUnzippedBytes;
  static const defaultMaxUnzippedBytes = 256 * 1024 * 1024;

  static final _aes = DartAesGcm();
  static const _macLength = 16;
  static const _shaPrefix = 'sha256:';

  /// The whole file for [tables]. With a [password], the payload is encrypted.
  Future<Uint8List> encode(
    BackupTables tables, {
    required String appVersion,
    required DateTime now,
    String? password,
  }) async {
    final zipped = const GZipEncoder().encodeBytes(utf8.encode(jsonEncode({'tables': tables})));
    final days = [
      for (final row in tables['transactions'] ?? const <Map<String, Object?>>[]) row['localDay'],
    ].whereType<int>().toList();

    final derived = password == null ? null : await keys.forNewBackup(password);
    final nonce = derived == null ? null : _aes.newNonce();
    final header = BackupHeader(
      formatVersion: BackupFormat.version,
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      createdAt: now,
      counts: {for (final t in BackupFormat.tables) t: tables[t]?.length ?? 0},
      firstDay: days.isEmpty ? null : days.reduce((a, b) => a < b ? a : b),
      lastDay: days.isEmpty ? null : days.reduce((a, b) => a > b ? a : b),
      kdf: derived?.params,
      nonce: nonce,
    );
    final headerBytes = utf8.encode(jsonEncode(header.toJson()));

    List<int> payload = zipped;
    if (derived != null) {
      final box = await _aes.encrypt(
        zipped,
        secretKey: SecretKey(derived.key),
        nonce: nonce!,
        aad: headerBytes,
      );
      payload = [...box.cipherText, ...box.mac.bytes];
    }

    return (BytesBuilder(copy: false)
          ..add(utf8.encode('${BackupFormat.magic}\n'))
          ..add(headerBytes)
          ..add(utf8.encode('\n$_shaPrefix${await _sha256([...headerBytes, ...payload])}\n'))
          ..add(payload))
        .takeBytes();
  }

  /// Reads only the header, without a password. Throws [BackupException] for a file that is
  /// not an Akatabo backup, is damaged, or is from a newer version of Akatabo.
  BackupHeader readHeader(Uint8List bytes) => _split(bytes).header;

  /// Opens the file and returns its tables. Throws [BackupException].
  Future<BackupTables> decode(Uint8List bytes, {String? password}) async {
    final parts = _split(bytes);
    final header = parts.header;
    final payload = parts.payload;
    if (await _sha256([...parts.headerBytes, ...payload]) != parts.sha) {
      throw const BackupException(BackupProblem.damaged);
    }

    List<int> zipped = payload;
    if (header.isProtected) {
      if (password == null || password.isEmpty) {
        throw const BackupException(BackupProblem.passwordNeeded);
      }
      if (payload.length < _macLength) throw const BackupException(BackupProblem.damaged);
      final key = await keys.forExisting(password, header.kdf!);
      try {
        zipped = await _aes.decrypt(
          SecretBox(
            payload.sublist(0, payload.length - _macLength),
            nonce: header.nonce!,
            mac: Mac(payload.sublist(payload.length - _macLength)),
          ),
          secretKey: SecretKey(key),
          aad: parts.headerBytes,
        );
      } on SecretBoxAuthenticationError {
        // The payload hash matched, so the bytes are as they were saved: the key is wrong.
        throw const BackupException(BackupProblem.wrongPassword);
      }
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(_gunzip(zipped)));
    } catch (_) {
      throw const BackupException(BackupProblem.damaged);
    }
    return _tablesFrom(decoded);
  }

  /// Unzips [zipped] a slice at a time, counting what comes out, and stops once it passes
  /// [maxUnzippedBytes] (a "zip bomb": a small file that unzips to gigabytes).
  Uint8List _gunzip(List<int> zipped) {
    final out = _CappedBytes(maxUnzippedBytes);
    final input = GZipCodec().decoder.startChunkedConversion(out);
    const slice = 64 * 1024;
    for (var i = 0; i < zipped.length; i += slice) {
      input.add(zipped.sublist(i, i + slice > zipped.length ? zipped.length : i + slice));
    }
    input.close();
    return out.bytes.takeBytes();
  }

  ({BackupHeader header, List<int> headerBytes, String sha, Uint8List payload}) _split(
    Uint8List bytes,
  ) {
    final magic = utf8.encode('${BackupFormat.magic}\n');
    final shared = bytes.length < magic.length ? bytes.length : magic.length;
    for (var i = 0; i < shared; i++) {
      if (bytes[i] != magic[i]) throw const BackupException(BackupProblem.notAkatabo);
    }
    // Empty, or the start of the marker and nothing more: cut short while copying.
    if (bytes.length <= magic.length) {
      throw BackupException(bytes.isEmpty ? BackupProblem.notAkatabo : BackupProblem.damaged);
    }

    final headerEnd = bytes.indexOf(0x0A, magic.length);
    if (headerEnd < 0 || headerEnd - magic.length > BackupFormat.maxHeaderBytes) {
      throw const BackupException(BackupProblem.damaged);
    }
    final headerBytes = Uint8List.sublistView(bytes, magic.length, headerEnd);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(headerBytes));
    } catch (_) {
      throw const BackupException(BackupProblem.damaged);
    }
    final header = _headerFrom(json);

    final shaEnd = bytes.indexOf(0x0A, headerEnd + 1);
    if (shaEnd < 0) throw const BackupException(BackupProblem.damaged);
    final String shaLine;
    try {
      shaLine = utf8.decode(bytes.sublist(headerEnd + 1, shaEnd));
    } on FormatException {
      throw const BackupException(BackupProblem.damaged);
    }
    if (!shaLine.startsWith(_shaPrefix)) throw const BackupException(BackupProblem.damaged);
    return (
      header: header,
      headerBytes: headerBytes,
      sha: shaLine.substring(_shaPrefix.length),
      payload: Uint8List.sublistView(bytes, shaEnd + 1),
    );
  }

  BackupHeader _headerFrom(Object? json) {
    if (json is! Map || json['format'] != BackupFormat.name) {
      throw const BackupException(BackupProblem.damaged);
    }
    final formatVersion = json['formatVersion'];
    final schema = json['schemaVersion'];
    final app = json['appVersion'];
    if (formatVersion is! int || schema is! int) {
      throw const BackupException(BackupProblem.damaged);
    }
    // Checked before anything else is trusted: a newer file may lay out the rest differently.
    if (formatVersion > BackupFormat.version || schema > schemaVersion) {
      throw BackupException(BackupProblem.newerVersion, appVersion: app is String ? app : null);
    }
    final created = DateTime.tryParse('${json['createdAt']}');
    final counts = json['counts'];
    if (app is! String || created == null || counts is! Map) {
      throw const BackupException(BackupProblem.damaged);
    }
    KdfParams? kdf;
    List<int>? nonce;
    if (json['protected'] == true) {
      kdf = KdfParams.fromJson(json['kdf']);
      try {
        nonce = base64Decode('${json['nonce']}');
      } on FormatException {
        nonce = null;
      }
      if (kdf == null || nonce == null || nonce.length != 12) {
        throw const BackupException(BackupProblem.damaged);
      }
    }
    int? day(Object? v) => v is int ? v : null;
    return BackupHeader(
      formatVersion: formatVersion,
      schemaVersion: schema,
      appVersion: app,
      createdAt: created,
      counts: {
        for (final e in counts.entries)
          if (e.value is int) '${e.key}': e.value as int,
      },
      firstDay: day(json['firstDay']),
      lastDay: day(json['lastDay']),
      kdf: kdf,
      nonce: nonce,
    );
  }

  BackupTables _tablesFrom(Object? decoded) {
    if (decoded is! Map || decoded['tables'] is! Map) {
      throw const BackupException(BackupProblem.damaged);
    }
    final raw = decoded['tables'] as Map;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final name in BackupFormat.tables) {
      final rows = raw[name] ?? const <Object?>[];
      if (rows is! List) throw const BackupException(BackupProblem.damaged);
      tables[name] = [
        for (final row in rows)
          if (row is Map<String, Object?>)
            row
          else
            throw const BackupException(BackupProblem.damaged),
      ];
    }
    return tables;
  }

  static Future<String> _sha256(List<int> bytes) async {
    final hash = await const DartSha256().hash(bytes);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Collects unzipped bytes and throws once there are more than [cap].
class _CappedBytes implements Sink<List<int>> {
  _CappedBytes(this.cap);
  final int cap;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    bytes.add(chunk);
    if (bytes.length > cap) throw const BackupException(BackupProblem.damaged);
  }

  @override
  void close() {}
}
