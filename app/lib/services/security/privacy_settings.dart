import '../../data/settings/setting_keys.dart';

/// How the lock screen is opened: the PIN alone, or fingerprint or face with the PIN as the
/// fallback. The PIN always works.
enum UnlockMethod { pin, biometric }

/// "Lock after": how long Akatabo can be out of sight before it asks again.
enum LockAfter {
  rightAway(Duration.zero, 'Right away'),
  oneMinute(Duration(minutes: 1), '1 minute away'),
  fiveMinutes(Duration(minutes: 5), '5 minutes away'),
  fifteenMinutes(Duration(minutes: 15), '15 minutes away');

  const LockAfter(this.away, this.label);

  /// Time out of sight after which the app locks. Zero locks each time it is hidden.
  final Duration away;

  /// As the Lock after row and its choice sheet show it.
  final String label;
}

/// The Privacy and security settings, kept in the same settings table as every other row.
///
/// Whether the lock is on lives here, so "Delete everything" (which clears the table) also
/// switches it off. The PIN itself never touches the database: only a hash of it, in the
/// phone's secure storage (see `PinStore`).
abstract final class PrivacyKeys {
  /// Off until the person sets a PIN. The lock only applies when a PIN is also stored.
  static const lockOn = BoolSetting('privacy.lockOn', false);
  static const unlockWith = EnumSetting(
    'privacy.unlockWith',
    UnlockMethod.pin,
    UnlockMethod.values,
  );

  /// One minute, as drawn.
  static const lockAfter = EnumSetting('privacy.lockAfter', LockAfter.oneMinute, LockAfter.values);
  static const hideAmounts = BoolSetting('privacy.hideAmounts', false);

  /// On, as drawn: figures stay out of the recent-apps view unless the person switches it off.
  static const blankInSwitcher = BoolSetting('privacy.blankInSwitcher', true);
}

/// The number of digits in a PIN. Four, as the drawn lock screen shows four dots.
const pinLength = 4;
