import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../services/backup/backup_files.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/backup_settings.dart';
import '../../services/backup/weekly_backup.dart';
import '../../services/security/lock_controller.dart';
import '../../widgets/ak_message.dart';
import 'backup_password.dart';

/// "19 Nov 2026", or "Never" before the first backup.
String formatBackupDay(int millis) => millis <= 0
    ? 'Never'
    : DateFormat('d MMM y').format(DateTime.fromMillisecondsSinceEpoch(millis));

/// The backup actions shared by Export and back up, Privacy and data, and the weekly
/// reminder at start-up. Each returns a sentence for the person, or null when they backed
/// out and nothing needs saying.
class BackupActions {
  BackupActions(this._ref);
  final WidgetRef _ref;

  /// Runs a system file or folder dialog without the app lock treating it as "away".
  Future<T> _whilePicking<T>(Future<T> Function() dialog) =>
      _ref.read(lockControllerProvider.notifier).keepUnlockedWhile(dialog);

  static const failed =
      'The backup could not be saved. Nothing changed on this phone. Try again, or pick '
      'another place to save it.';

  Future<String?> _passwordIfProtected(BuildContext context, {String? purpose}) async {
    final protect = await _ref.read(settingsRepositoryProvider).read(BackupKeys.protect);
    if (!protect) return '';
    // Protection is on: a screen that closed meanwhile backs out, never saves unprotected.
    if (!context.mounted) return null;
    return askNewBackupPassword(context, purpose: purpose);
  }

  /// "Save a backup file now": asks for the password when protection is on, makes the file,
  /// and lets the person choose where it goes.
  Future<String?> saveNow(BuildContext context, {VoidCallback? onWorking}) async {
    final service = _ref.read(backupServiceProvider);
    try {
      final password = await _passwordIfProtected(context);
      if (password == null) return null;
      onWorking?.call();
      final bytes = await service.createFile(password: password.isEmpty ? null : password);
      final saved = await _whilePicking(
        () => _ref.read(backupFilesProvider).save(bytes, BackupService.fileNameFor(clock.now())),
      );
      if (!saved) return 'Not saved. The backup file was not kept anywhere.';
      await _recordSaved(service);
      return password.isEmpty
          ? 'Backup saved. Keep it somewhere other than this phone.'
          : 'Backup saved with your password. Keep it somewhere other than this phone.';
    } catch (error, stack) {
      _report(error, stack);
      return failed;
    }
  }

  /// Picks a folder and backs up into it now. Used when weekly backup is switched on, and
  /// when it is due after the app was closed (the folder is not kept across a restart).
  /// True when the backup was written.
  Future<(bool, String?)> backupIntoPickedFolder(
    BuildContext context, {
    VoidCallback? onWorking,
  }) async {
    final BackupFolder? folder;
    try {
      folder = await _whilePicking(() => _ref.read(backupFilesProvider).pickFolder());
    } catch (error, stack) {
      _report(error, stack);
      return (false, failed);
    }
    if (folder == null) {
      return (false, 'No folder was picked, so no weekly backup was saved.');
    }
    if (!context.mounted) return (false, null);
    final String? password;
    try {
      password = await _passwordIfProtected(
        context,
        purpose: 'This week\'s backup goes to the folder you picked.',
      );
    } catch (error, stack) {
      // The protect setting could not be read: never fall back to an unprotected backup.
      _report(error, stack);
      return (false, failed);
    }
    if (password == null) return (false, null);
    onWorking?.call();
    final service = _ref.read(backupServiceProvider);
    try {
      final bytes = await service.createFile(password: password.isEmpty ? null : password);
      final into = folder;
      await _whilePicking(
        () => _ref
            .read(backupFilesProvider)
            .saveInto(into, bytes, BackupService.fileNameFor(clock.now())),
      );
      await _recordSaved(service);
      _ref.read(weeklyFolderProvider.notifier).set(folder);
      return (true, 'Backed up to your folder. The next one is due in a week.');
    } catch (error, stack) {
      _report(error, stack);
      return (false, failed);
    }
  }

  /// "Back up by itself every week". Switching on picks the folder and backs up at once,
  /// so the person sees that it works; it stays off if they back out.
  Future<String?> setWeekly(BuildContext context, bool on, {VoidCallback? onWorking}) async {
    final settings = _ref.read(settingsRepositoryProvider);
    if (!on) {
      try {
        await settings.write(BackupKeys.weekly, false);
      } catch (error, stack) {
        _report(error, stack);
        return notChanged;
      }
      _ref.read(weeklyFolderProvider.notifier).set(null);
      return null;
    }
    final (saved, message) = await backupIntoPickedFolder(context, onWorking: onWorking);
    if (saved) {
      try {
        await settings.write(BackupKeys.weekly, true);
      } catch (error, stack) {
        _report(error, stack);
        return 'This week\'s backup was saved, but weekly backup could not be switched on. '
            'Try again.';
      }
    }
    return message;
  }

  static const notChanged = 'That could not be changed. Try again.';

  /// "Protect with a password". Returns a sentence only when the change could not be saved,
  /// so the person never believes the next backup is protected when it is not.
  Future<String?> setProtect(bool on) async {
    try {
      await _ref.read(settingsRepositoryProvider).write(BackupKeys.protect, on);
      return null;
    } catch (error, stack) {
      _report(error, stack);
      return notChanged;
    }
  }

  /// Notes the backup's date. The file is already safe, so a failure here is reported but
  /// does not turn a saved backup into "could not be saved".
  Future<void> _recordSaved(BackupService service) async {
    try {
      await service.recordSaved();
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  static void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo backup'),
  );
}

/// Shows [message] at the foot of the screen, when there is one.
void showBackupMessage(BuildContext context, String? message) => showAkMessage(context, message);
