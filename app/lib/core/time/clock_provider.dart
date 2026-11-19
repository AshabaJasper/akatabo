import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" for working out the day and the period on screen: today's label, the current month,
/// the same days last month. Tests fix it to 19 November 2026 by overriding it.
///
/// The value is kept, so every screen agrees on the day. It refreshes itself one second after
/// local midnight, and the app refreshes it when it comes back to the foreground (a phone
/// that sleeps can miss the timer).
///
/// Not for time stamps: a saved entry takes `clock.now()` at the moment of saving.
final appNowProvider = Provider<DateTime>((ref) {
  final now = clock.now();
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextDay.difference(now) + const Duration(seconds: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});
