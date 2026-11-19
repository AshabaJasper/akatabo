import 'package:akatabo/core/time/clock_provider.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('"now" stays put during the day and moves to the new day after midnight', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 11, 19, 23, 58)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final seen = <DateTime>[];
        container.listen(appNowProvider, (_, next) => seen.add(next), fireImmediately: true);

        async.elapse(const Duration(minutes: 1));
        expect(seen, hasLength(1), reason: 'no change before midnight');
        expect(container.read(appNowProvider).day, 19);

        async.elapse(const Duration(minutes: 1, seconds: 2));
        expect(container.read(appNowProvider).day, 20, reason: 'rolled over after midnight');

        async.elapse(const Duration(days: 1));
        expect(container.read(appNowProvider).day, 21, reason: 'keeps rolling each night');
      });
    });
  });

  test('the month rolls over on the 1st at midnight', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 11, 30, 23, 59, 30)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(appNowProvider, (_, _) {});
        async.elapse(const Duration(minutes: 1));
        final now = container.read(appNowProvider);
        expect((now.month, now.day), (12, 1));
      });
    });
  });

  test('disposing cancels the midnight timer', () {
    fakeAsync((async) {
      withClock(async.getClock(DateTime(2026, 11, 19, 9)), () {
        final container = ProviderContainer();
        container.read(appNowProvider);
        expect(async.pendingTimers, hasLength(1));
        container.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
