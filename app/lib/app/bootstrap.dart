import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../data/providers.dart';

/// Creates the app's provider container with the stored settings already read, so the
/// first frame uses the person's theme, main colour, corners, text size and periods instead
/// of the defaults followed by a switch. The splash screen stays up while this runs.
Future<ProviderContainer> createAppContainer({List<Override> overrides = const []}) async {
  // Retry is off: every provider reads the local database, so an error is real and should
  // show at once rather than after silent retries.
  final container = ProviderContainer(retry: (_, _) => null, overrides: overrides);
  // Riverpod pauses a provider nobody listens to, and a plain read is not a listener: the
  // settings stream would never deliver its first value. This listener lives as long as
  // the container, which is the app's lifetime.
  container.listen(storedSettingsProvider, (_, _) {});
  try {
    // Never keep the splash screen up for long: a slow or broken database falls back to
    // the drawn defaults and the theme updates when the settings arrive.
    await container.read(storedSettingsProvider.future).timeout(const Duration(seconds: 3));
  } catch (error, stack) {
    // The theme falls back to the drawn defaults; screens that need the database show
    // their own error.
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo startup'),
    );
  }
  return container;
}
