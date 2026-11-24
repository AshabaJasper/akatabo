import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A phone settings page Akatabo can open for the person.
enum PhoneSettingsPage {
  /// Akatabo's own notification settings.
  notifications('notifications'),

  /// Where fingerprints or a face are added (the security settings on older phones).
  biometrics('biometrics'),

  /// Akatabo's app info page, with every permission.
  app('app');

  const PhoneSettingsPage(this.key);
  final String key;
}

/// What the phone reports about Akatabo's permissions. Read only: the person changes them in
/// the phone's own settings, which [open] takes them to.
abstract interface class PhonePermissions {
  /// Each permission this build asks for (`android.permission.…`), mapped to whether it is
  /// granted now. Null where the phone cannot say (iOS, or the call failed).
  Future<Map<String, bool>?> requested();

  /// Opens [page] in the phone's settings. False if no page could be opened.
  Future<bool> open(PhoneSettingsPage page);
}

final phonePermissionsProvider = Provider<PhonePermissions>((ref) => ChannelPhonePermissions());

/// [PhonePermissions] over the "akatabo/permissions" channel in `MainActivity`.
class ChannelPhonePermissions implements PhonePermissions {
  ChannelPhonePermissions([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('akatabo/permissions');
  final MethodChannel _channel;

  @override
  Future<Map<String, bool>?> requested() async {
    try {
      final raw = await _channel.invokeMapMethod<String, bool>('requested');
      return raw == null ? null : Map.unmodifiable(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> open(PhoneSettingsPage page) async {
    try {
      return await _channel.invokeMethod<bool>('open', page.key) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// A permission in words: its name, what Akatabo uses it for, and whether it belongs only to
/// test builds. Unknown permissions fall back to their system name.
typedef PermissionWords = ({String name, String use, bool testBuildOnly});

const _android = 'android.permission.';

PermissionWords permissionWords(String permission) => switch (permission) {
  '${_android}POST_NOTIFICATIONS' => (
    name: 'Notifications',
    use: 'Only for reminders you switch on',
    testBuildOnly: false,
  ),
  '${_android}USE_BIOMETRIC' => (
    name: 'Fingerprint or face',
    use: 'To unlock Akatabo without the PIN',
    testBuildOnly: false,
  ),
  // Flutter adds these to debug builds for hot reload. The released app strips INTERNET in
  // its manifest, so it has no internet access at all.
  '${_android}INTERNET' => (
    name: 'Internet',
    use: 'For development only. The released app has no internet access',
    testBuildOnly: true,
  ),
  '${_android}ACCESS_LOCAL_NETWORK' => (
    name: 'Local network',
    use: 'For development only. The released app does not ask for it',
    testBuildOnly: true,
  ),
  _ => (
    name: permission.startsWith(_android) ? permission.substring(_android.length) : permission,
    use: 'Asked for by a part of the app',
    testBuildOnly: false,
  ),
};

/// Kinds of access people worry about, with the permissions that would grant them. The page
/// lists those Akatabo never asks for, worked out from what the phone reports.
const sensitiveAccess = <(String, List<String>)>[
  ('internet', ['${_android}INTERNET']),
  ('location', ['${_android}ACCESS_FINE_LOCATION', '${_android}ACCESS_COARSE_LOCATION']),
  ('contacts', ['${_android}READ_CONTACTS']),
  ('camera', ['${_android}CAMERA']),
  ('microphone', ['${_android}RECORD_AUDIO']),
  ('text messages', ['${_android}READ_SMS', '${_android}RECEIVE_SMS']),
  (
    'your files and photos',
    [
      '${_android}READ_EXTERNAL_STORAGE',
      '${_android}WRITE_EXTERNAL_STORAGE',
      '${_android}READ_MEDIA_IMAGES',
    ],
  ),
];

/// The kinds of access in [sensitiveAccess] that none of [requested] grants.
List<String> neverAskedFor(Iterable<String> requested) {
  final asked = requested.toSet();
  return [
    for (final (label, permissions) in sensitiveAccess)
      if (!permissions.any(asked.contains)) label,
  ];
}

/// "a, b and c".
String joinWords(List<String> words) => switch (words.length) {
  0 => '',
  1 => words.single,
  _ => '${words.sublist(0, words.length - 1).join(', ')} and ${words.last}',
};
