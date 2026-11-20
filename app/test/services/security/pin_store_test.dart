import 'package:akatabo/services/security/pin_hasher.dart';
import 'package:akatabo/services/security/pin_store.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_security.dart';

void main() {
  group('PinHasher', () {
    test('stores a salted PBKDF2 hash, never the PIN, and checks it', () async {
      final hasher = fastHasher();
      final record = await hasher.hash('2580');
      expect(record, startsWith(r'pbkdf2-sha256$10$'));
      expect(record, isNot(contains('2580')));
      expect(await hasher.verify('2580', record), isTrue);
      expect(await hasher.verify('2581', record), isFalse);
    });

    test('two hashes of the same PIN differ (random salt)', () async {
      final hasher = fastHasher();
      expect(await hasher.hash('1111'), isNot(await hasher.hash('1111')));
    });

    test('a damaged record never matches', () async {
      final hasher = fastHasher();
      expect(await hasher.verify('1111', 'nonsense'), isFalse);
      expect(await hasher.verify('1111', r'pbkdf2-sha256$x$AAAA$AAAA'), isFalse);
      expect(await hasher.verify('1111', r'pbkdf2-sha256$10$***$***'), isFalse);
    });

    test('the app hashes on a background isolate with the default count', () async {
      final app = PinHasher();
      expect(app.iterations, PinHasher.defaultIterations);
      expect(app.inBackground, isTrue);
      final quick = PinHasher(iterations: 10);
      final record = await quick.hash('4826');
      expect(await quick.verify('4826', record), isTrue);
      expect(await quick.verify('4825', record), isFalse);
    });
  });

  group('PinStore', () {
    final start = DateTime(2026, 11, 19, 9, 14);

    test('waits grow after four free wrong tries', () {
      expect(PinStore.waitAfter(4), Duration.zero);
      expect(PinStore.waitAfter(5), const Duration(seconds: 30));
      expect(PinStore.waitAfter(6), const Duration(minutes: 1));
      expect(PinStore.waitAfter(7), const Duration(minutes: 5));
      expect(PinStore.waitAfter(8), const Duration(minutes: 15));
      expect(PinStore.waitAfter(20), const Duration(hours: 1));
    });

    test('the right PIN is accepted and clears wrong tries', () async {
      final values = await valuesWithPin('2580');
      final store = PinStore(values, fastHasher());
      expect(await store.check('0000'), isA<PinRejected>());
      expect(await store.check('2580'), isA<PinAccepted>());
      expect(values.values.keys, ['akatabo.pin.hash']);
    });

    test('a wait survives a restart and ends on time', () async {
      final values = await valuesWithPin('2580');
      await withClock(Clock.fixed(start), () async {
        final store = PinStore(values, fastHasher());
        for (var i = 1; i <= 4; i++) {
          final r = await store.check('0000') as PinRejected;
          expect(r.wait, Duration.zero);
          expect(r.triesBeforeWait, 4 - i);
        }
        final fifth = await store.check('0000') as PinRejected;
        expect(fifth.wait, const Duration(seconds: 30));
      });

      // The app is closed and opened again: a new store over the same secure storage.
      await withClock(Clock.fixed(start.add(const Duration(seconds: 10))), () async {
        final reopened = PinStore(values, fastHasher());
        expect(await reopened.currentWait(), const Duration(seconds: 20));
        // Even the right PIN is not checked during the wait.
        expect(await reopened.check('2580'), isA<PinMustWait>());
      });

      await withClock(Clock.fixed(start.add(const Duration(seconds: 31))), () async {
        final later = PinStore(values, fastHasher());
        expect(await later.currentWait(), Duration.zero);
        final sixth = await later.check('0000') as PinRejected;
        expect(sixth.wait, const Duration(minutes: 1));
        await withClock(
          Clock.fixed(start.add(const Duration(seconds: 92))),
          () async => expect(await later.check('2580'), isA<PinAccepted>()),
        );
      });
    });

    test('a phone clock set backwards cannot stretch a wait', () async {
      final values = await valuesWithPin('2580');
      final store = PinStore(values, fastHasher());
      await withClock(Clock.fixed(start), () async {
        for (var i = 0; i < 5; i++) {
          await store.check('0000');
        }
      });
      await withClock(Clock.fixed(start.subtract(const Duration(days: 30))), () async {
        expect(await store.currentWait(), const Duration(seconds: 30));
      });
    });

    test('moving the date forward does not end a wait early', () async {
      final values = await valuesWithPin('2580');
      var boot = 1000000;
      final store = PinStore(values, fastHasher(), sinceBoot: () async => boot);
      await withClock(Clock.fixed(start), () async {
        for (var i = 0; i < 5; i++) {
          await store.check('0000');
        }
      });
      boot += 10000; // Ten real seconds pass while the date jumps two hours ahead.
      await withClock(Clock.fixed(start.add(const Duration(hours: 2))), () async {
        expect(await store.currentWait(), const Duration(seconds: 20));
        expect(await store.check('2580'), isA<PinMustWait>());
      });
      boot += 20000;
      await withClock(Clock.fixed(start.add(const Duration(hours: 2))), () async {
        expect(await store.check('2580'), isA<PinAccepted>());
      });
    });

    test('moving the date back starts the wait again, once', () async {
      final values = await valuesWithPin('2580');
      final store = PinStore(values, fastHasher());
      await withClock(Clock.fixed(start), () async {
        for (var i = 0; i < 5; i++) {
          await store.check('0000');
        }
      });
      final back = start.subtract(const Duration(hours: 1));
      await withClock(Clock.fixed(back.add(const Duration(seconds: 25))), () async {
        expect(await store.currentWait(), const Duration(seconds: 30));
      });
      await withClock(Clock.fixed(back.add(const Duration(seconds: 40))), () async {
        expect(await store.currentWait(), const Duration(seconds: 15));
      });
    });

    test('clear removes the PIN and the wrong tries', () async {
      final values = await valuesWithPin('2580');
      final store = PinStore(values, fastHasher());
      await store.check('0000');
      await store.clear();
      expect(values.values, isEmpty);
      expect(await store.hasPin(), isFalse);
    });
  });
}
