import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Blank the screen in the app switcher", through the `akatabo/privacy` channel in
/// `MainActivity.kt`. Tests use a fake.
abstract interface class PrivacyWindow {
  Future<void> setHiddenInRecents(bool hidden);
}

final privacyWindowProvider = Provider<PrivacyWindow>((ref) => ChannelPrivacyWindow());

class ChannelPrivacyWindow implements PrivacyWindow {
  ChannelPrivacyWindow([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('akatabo/privacy');
  final MethodChannel _channel;

  /// Android 13 and later hide the thumbnail in recent apps; older Android versions block
  /// screenshots of the app as well. Other platforms have no handler and do nothing.
  @override
  Future<void> setHiddenInRecents(bool hidden) async {
    try {
      await _channel.invokeMethod<void>('setHiddenInRecents', hidden);
    } on MissingPluginException {
      // iOS and tests: no handler.
    }
  }
}
