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
    final password = await _passwordIfProtected(context);
    if (password == null) return null;
    onWorking?.call();
    final service = _ref.read(backupServiceProvider);
    try {
      final bytes = await service.createFile(password: password.isEmpty ? null : password);
      final saved = await _whilePicking(
        () => _ref.read(backupFilesProvider).save(bytes, BackupService.fileNameFor(clock.now())),
      );
      if (!saved) return 'Not saved. The backup file was not kept anywhere.';
      await service.recordSaved();
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
    final password = await _passwordIfProtected(
      context,
      purpose: 'This week\'s backup goes to the folder you picked.',
    );
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
      await service.recordSaved();
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
      await settings.write(BackupKeys.weekly, false);
      _ref.read(weeklyFolderProvider.notifier).set(null);
      return null;
    }
    final (saved, message) = await backupIntoPickedFolder(context, onWorking: onWorking);
    if (saved) await settings.write(BackupKeys.weekly, true);
    return message;
  }

  Future<void> setProtect(bool on) =>
      _ref.read(settingsRepositoryProvider).write(BackupKeys.protect, on);

  static void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo backup'),
  );
}

/// Shows [message] at the foot of the screen, when there is one.
void showBackupMessage(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
