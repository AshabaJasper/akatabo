import 'dart:convert';
import 'dart:typed_data';

import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/key_derivation.dart';
import 'package:archive/archive.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backup.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

BackupTables _tables() => {
  'accounts': [
    {'id': 'acct.mtn', 'name': 'MTN MoMo', 'updatedAt': 1},
  ],
  'categories': [
    {'id': 'cat.food', 'name': 'Food and shopping', 'monthlyBudget': 300000, 'updatedAt': 1},
  ],
  'regularPayments': [],
  'transactions': [
    {'id': 't1', 'amount': 45000, 'localDay': 20260301, 'updatedAt': 5},
    {'id': 't2', 'amount': 1200, 'localDay': 20261112, 'updatedAt': 6},
  ],
  'settings': [
    {'key': 'general.monthStartsOn', 'value': '25', 'updatedAt': 3},
  ],
  'forecastSnapshots': [],
};

Future<Uint8List> _encode(BackupCodec codec, {String? password, BackupTables? tables}) =>
    codec.encode(tables ?? _tables(), appVersion: '0.1.0+1', now: _now, password: password);

/// The file's three text lines and its payload.
({String magic, Map<String, Object?> header, String sha, Uint8List payload}) _parts(
  Uint8List bytes,
) {
  final a = bytes.indexOf(10);
  final b = bytes.indexOf(10, a + 1);
  final c = bytes.indexOf(10, b + 1);
  return (
    magic: utf8.decode(bytes.sublist(0, a)),
    header: jsonDecode(utf8.decode(bytes.sublist(a + 1, b))) as Map<String, Object?>,
    sha: utf8.decode(bytes.sublist(b + 1, c)),
    payload: Uint8List.fromList(bytes.sublist(c + 1)),
  );
}

/// Builds a file by hand from a header and a payload, with a correct hash line.
Future<Uint8List> _build(Map<String, Object?> header, List<int> payload) async {
  final h = utf8.encode(jsonEncode(header));
  final hash = await const DartSha256().hash([...h, ...payload]);
  final hex = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return Uint8List.fromList([
    ...utf8.encode('AKATABO-BACKUP\n'),
    ...h,
    ...utf8.encode('\nsha256:$hex\n'),
    ...payload,
  ]);
}

Future<BackupProblem?> _problemOf(Future<Object?> Function() run) async {
  try {
    await run();
    return null;
  } on BackupException catch (e) {
    return e.problem;
  }
}

void main() {
  group('round trip', () {
    test('without a password, the tables come back equal', () async {
      final codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
      final bytes = await _encode(codec);
      expect(await codec.decode(bytes), _tables());
    });

    test('with a password, the tables come back equal and the payload is unreadable', () async {
      final keys = CountingKeys();
      final codec = BackupCodec(schemaVersion: 3, keys: keys.deriver);
      final bytes = await _encode(codec, password: 'kampala-2026');
      expect(await codec.decode(bytes, password: 'kampala-2026'), _tables());
      // No figure or name from the tables is readable anywhere in the file.
      final text = latin1.decode(bytes);
      expect(text, isNot(contains('MTN MoMo')));
      expect(text, isNot(contains('45000')));
      expect(
        () => const GZipDecoder().decodeBytes(_parts(bytes).payload, verify: true),
        throwsA(anything),
      );
    });

    test('with real Argon2id on an isolate, the file opens with the password', () async {
      final codec = BackupCodec(schemaVersion: 3);
      final bytes = await _encode(codec, password: 'correct horse');
      final kdf = _parts(bytes).header['kdf']! as Map;
      expect(kdf['name'], 'argon2id');
      expect(kdf['memoryKiB'], 19456);
      expect(kdf['millis'], isA<int>());
      expect(await codec.decode(bytes, password: 'correct horse'), _tables());
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('the readable header', () {
    test('says format, versions, counts and entry days, and nothing private', () async {
      final codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
      final parts = _parts(await _encode(codec));
      expect(parts.magic, 'AKATABO-BACKUP');
      expect(parts.sha, startsWith('sha256:'));
      final h = parts.header;
      expect(h['format'], 'akatabo-backup');
      expect(h['formatVersion'], 1);
      expect(h['schemaVersion'], 3);
      expect(h['appVersion'], '0.1.0+1');
      expect(h['counts'], {
        'accounts': 1,
        'categories': 1,
        'regularPayments': 0,
        'transactions': 2,
        'settings': 1,
        'forecastSnapshots': 0,
      });
      expect(h['firstDay'], 20260301);
      expect(h['lastDay'], 20261112);
      expect(h['protected'], false);
      expect(h.containsKey('kdf'), isFalse);
    });

    test('a protected file records the key settings and salt', () async {
      final codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
      final h = _parts(await _encode(codec, password: 'secret1')).header;
      expect(h['protected'], true);
      final kdf = h['kdf']! as Map;
      expect(kdf['name'], 'argon2id');
      expect(kdf['iterations'], 2);
      expect(kdf['parallelism'], 1);
      expect(base64Decode(kdf['salt']! as String), hasLength(16));
      expect(base64Decode(h['nonce']! as String), hasLength(12));
      expect(kdf['fellBackFromArgon2id'], false);
    });

    test('readHeader needs no password', () async {
      final codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
      final header = codec.readHeader(await _encode(codec, password: 'secret1'));
      expect(header.isProtected, isTrue);
      expect(header.counts['transactions'], 2);
    });
  });

  group('key derivation', () {
    test('falls back to PBKDF2 when Argon2id is over budget, and says so', () async {
      final keys = CountingKeys()..argonSlow = true;
      final codec = BackupCodec(schemaVersion: 3, keys: keys.deriver);
      final bytes = await _encode(codec, password: 'secret1');
      final kdf = _parts(bytes).header['kdf']! as Map;
      expect(kdf['name'], 'pbkdf2-sha256');
      expect(kdf['iterations'], 310000);
      expect(kdf['fellBackFromArgon2id'], true);
      expect(kdf['millis'], isA<int>());
      expect(await codec.decode(bytes, password: 'secret1'), _tables());

      // The slow attempt is remembered: the next backup goes straight to PBKDF2.
      await _encode(codec, password: 'secret1');
      expect(keys.tries, 1);
    });

    test('a real isolate past its deadline is stopped and gives no key', () async {
      final key = await deriveInIsolateWithin(
        'secret1',
        KdfParams.argon2id(List.filled(16, 1)),
        Duration.zero,
      );
      expect(key, isNull);
    });

    test('real PBKDF2 and Argon2id give different 32-byte keys for one password', () async {
      final salt = List<int>.filled(16, 7);
      final a = await deriveKeyNow(
        'pw',
        KdfParams(name: KdfParams.argon2idName, iterations: 1, memoryKiB: 64, salt: salt),
      );
      final p = await deriveKeyNow(
        'pw',
        KdfParams(name: KdfParams.pbkdf2Name, iterations: 1000, salt: salt),
      );
      expect(a, hasLength(32));
      expect(p, hasLength(32));
      expect(a, isNot(p));
    });

    test('a header asking for absurd work is refused as damaged', () {
      expect(
        KdfParams.fromJson({
          'name': 'argon2id',
          'iterations': 2,
          'memoryKiB': 4000000,
          'parallelism': 1,
          'salt': base64Encode(List.filled(16, 1)),
        }),
        isNull,
      );
    });

    group('the most work a header may ask for', () {
      final salt = base64Encode(List.filled(16, 1));
      KdfParams? argon(int memory, int passes, int lanes) => KdfParams.fromJson({
        'name': 'argon2id',
        'iterations': passes,
        'memoryKiB': memory,
        'parallelism': lanes,
        'salt': salt,
      });
      KdfParams? pbkdf2(int rounds) =>
          KdfParams.fromJson({'name': 'pbkdf2-sha256', 'iterations': rounds, 'salt': salt});

      test('what Akatabo writes, and a little more, is accepted', () {
        expect(argon(19456, 2, 1), isNotNull);
        expect(argon(65536, 4, 4), isNotNull);
        expect(pbkdf2(310000), isNotNull);
        expect(pbkdf2(1000000), isNotNull);
      });

      test('more memory, passes, lanes or rounds than that is refused', () {
        expect(argon(262144, 2, 1), isNull);
        expect(argon(19456, 10, 1), isNull);
        expect(argon(19456, 2, 8), isNull);
        expect(argon(16, 2, 4), isNull, reason: 'less than 8 KiB a lane');
        expect(pbkdf2(5000000), isNull);
      });
    });
  });

  group('a payload that unzips to too much', () {
    final big = _tables()
      ..['settings'] = [
        {'key': 'general.note', 'value': 'a' * (1024 * 1024), 'updatedAt': 3},
      ];

    test('is refused as damaged rather than filling memory', () async {
      final small = BackupCodec(
        schemaVersion: 3,
        keys: CountingKeys().deriver,
        maxUnzippedBytes: 64 * 1024,
      );
      final bytes = await _encode(small, tables: big);
      expect(bytes.length, lessThan(64 * 1024), reason: 'the file itself is small');
      await expectLater(
        small.decode(bytes),
        throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.damaged)),
      );
    });

    test('opens under the usual limit', () async {
      final codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver);
      final tables = await codec.decode(await _encode(codec, tables: big));
      expect((tables['settings']!.single['value']! as String).length, 1024 * 1024);
    });
  });

  group('problems', () {
    late BackupCodec codec;
    setUp(() => codec = BackupCodec(schemaVersion: 3, keys: CountingKeys().deriver));

    test('the wrong password', () async {
      final bytes = await _encode(codec, password: 'right-one');
      expect(
        await _problemOf(() => codec.decode(bytes, password: 'wrong-one')),
        BackupProblem.wrongPassword,
      );
      expect(await _problemOf(() => codec.decode(bytes)), BackupProblem.passwordNeeded);
    });

    test('a truncated file', () async {
      for (final password in [null, 'right-one']) {
        final bytes = await _encode(codec, password: password);
        for (final keep in [5, 40, bytes.length - 10]) {
          expect(
            await _problemOf(() => codec.decode(bytes.sublist(0, keep), password: password)),
            BackupProblem.damaged,
            reason: 'kept $keep, password $password',
          );
        }
      }
    });

    test('a flipped byte in the payload is damage, not a wrong password', () async {
      for (final password in [null, 'right-one']) {
        final bytes = await _encode(codec, password: password);
        final copy = Uint8List.fromList(bytes);
        copy[copy.length - 20] ^= 0x01;
        expect(
          await _problemOf(() => codec.decode(copy, password: password)),
          BackupProblem.damaged,
        );
      }
    });

    test('a flipped byte in the header is damage', () async {
      final bytes = await _encode(codec, password: 'right-one');
      final text = utf8.decode(bytes.sublist(0, bytes.indexOf(10, 16)));
      final at = text.indexOf('"transactions":2') + '"transactions":'.length;
      final copy = Uint8List.fromList(bytes);
      copy[at] = '3'.codeUnitAt(0);
      expect(
        await _problemOf(() => codec.decode(copy, password: 'right-one')),
        BackupProblem.damaged,
      );
    });

    test('a payload that is not gzip', () async {
      final h = _parts(await _encode(codec)).header;
      final file = await _build(h, utf8.encode('this is not gzip at all'));
      expect(await _problemOf(() => codec.decode(file)), BackupProblem.damaged);
    });

    test('gzip that is not Akatabo tables', () async {
      final h = _parts(await _encode(codec)).header;
      final file = await _build(h, const GZipEncoder().encodeBytes(utf8.encode('[1,2,3]')));
      expect(await _problemOf(() => codec.decode(file)), BackupProblem.damaged);
    });

    test('a file that is not an Akatabo backup', () async {
      for (final other in [
        utf8.encode('Date,Description,Amount\n2026-11-19,Lunch,-12000\n'),
        Uint8List.fromList(List.generate(300, (i) => i % 256)),
        Uint8List(0),
      ]) {
        final bytes = Uint8List.fromList(other);
        expect(await _problemOf(() => codec.decode(bytes)), BackupProblem.notAkatabo);
        expect(await _problemOf(() async => codec.readHeader(bytes)), BackupProblem.notAkatabo);
      }
    });

    test('a file from a newer Akatabo is found before any decrypting', () async {
      final keys = CountingKeys();
      final newerCodec = BackupCodec(schemaVersion: 4, keys: keys.deriver);
      final bytes = await _encode(newerCodec, password: 'right-one');
      keys.full = 0;
      final mine = BackupCodec(schemaVersion: 3, keys: keys.deriver);
      try {
        mine.readHeader(bytes);
        fail('should refuse');
      } on BackupException catch (e) {
        expect(e.problem, BackupProblem.newerVersion);
        expect(e.appVersion, '0.1.0+1');
      }
      expect(await _problemOf(() => mine.decode(bytes)), BackupProblem.newerVersion);
      expect(keys.full, 0, reason: 'no key was made');

      final h = _parts(await _encode(codec)).header..['formatVersion'] = 2;
      final newerFormat = await _build(h, const [1, 2, 3]);
      expect(await _problemOf(() => codec.decode(newerFormat)), BackupProblem.newerVersion);
    });

    test('an older schema is accepted', () async {
      final older = BackupCodec(schemaVersion: 2, keys: CountingKeys().deriver);
      final bytes = await _encode(older);
      expect(await codec.decode(bytes), _tables());
    });
  });
}
