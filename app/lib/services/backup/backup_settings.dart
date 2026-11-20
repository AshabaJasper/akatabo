import '../../data/settings/setting_keys.dart';

/// The settings that belong to backing up. They are kept in the settings table like every
/// other setting, so they travel inside a backup file too, but they describe this phone's
/// backups, not the person's money: a restore never takes them from the file and never
/// removes them (see [isLocalOnlySetting]).
abstract final class BackupKeys {
  /// "Protect with a password". Drawn on, so a backup is protected unless switched off.
  static const protect = BoolSetting('backup.protect', true);

  /// "Back up by itself every week".
  static const weekly = BoolSetting('backup.weekly', false);

  /// When the last backup file was saved, from the button or the weekly backup, in
  /// milliseconds since the epoch. 0 means never.
  static const lastAt = IntSetting('backup.lastAt', 0, min: 0);
}

/// Setting keys that stay with the phone on restore, whichever way the person restores.
///
/// - `backup.`: when this phone last backed up, and whether it backs up weekly to a folder
///   that exists only on this phone.
/// - `lock.`, `privacy.`, `security.`: the app lock. The PIN itself lives in secure storage
///   and is never in a backup, so taking "lock on" from a file could lock the person out of
///   a phone that has no PIN.
/// - `app.onboardingDone`: the person has already been through the first run on this phone.
const localOnlySettingPrefixes = ['backup.', 'lock.', 'privacy.', 'security.'];
const localOnlySettingKeys = {'app.onboardingDone'};

bool isLocalOnlySetting(String key) =>
    localOnlySettingKeys.contains(key) || localOnlySettingPrefixes.any(key.startsWith);
