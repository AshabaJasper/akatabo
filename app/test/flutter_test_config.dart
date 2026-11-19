import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Today" in every test: 19 November 2026, 09:14, the date the screens were drawn for.
final testNow = DateTime(2026, 11, 19, 9, 14);

/// Runs [body] with `clock.now()` fixed at [testNow].
///
/// The test runner gives each test body its own zone, so a clock set around `testMain`
/// does not reach it; each test that reads the time wraps its body in this instead.
/// Widgets will read "today" through an app clock provider that widget tests override.
T atTestNow<T>(T Function() body) => withClock(Clock.fixed(testNow), body);

/// Loads the bundled fonts so goldens show real text instead of boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('Bricolage Grotesque', 'assets/fonts/BricolageGrotesque-Variable.ttf');
  await _loadFont('Geist', 'assets/fonts/Geist-Variable.ttf');
  await testMain();
}

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
