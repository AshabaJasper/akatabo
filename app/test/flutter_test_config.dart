import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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
  // Test fakes each open their own in-memory database, so drift's warning about one database
  // opened twice over the same connection does not apply here. The app opens exactly one.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Goldens are drawn on Windows and only match there (font rendering differs elsewhere).
  // CI's Linux job sets AKATABO_SKIP_GOLDENS=1, so every other check in a golden test still
  // runs while the image comparison passes; the Windows job compares the images for real.
  if (Platform.environment['AKATABO_SKIP_GOLDENS'] == '1') {
    goldenFileComparator = _SkippedGoldens();
  }
  await _loadFont('Bricolage Grotesque', 'assets/fonts/BricolageGrotesque-Variable.ttf');
  await _loadFont('Geist', 'assets/fonts/Geist-Variable.ttf');
  await testMain();
}

/// Accepts every golden without reading it; refuses to write one, so `--update-goldens`
/// cannot overwrite the Windows images with images drawn on another system.
class _SkippedGoldens extends GoldenFileComparator {
  _SkippedGoldens();

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) => throw StateError(
    'Goldens are switched off (AKATABO_SKIP_GOLDENS=1). Update them on Windows.',
  );
}

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
