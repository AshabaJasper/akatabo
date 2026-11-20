import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'backup_files.dart';
import 'backup_service.dart';
import 'backup_settings.dart';

/// How long after the last backup the weekly one is due.
const weeklyBackupEvery = Duration(days: 7);

/// Whether the weekly backup should run now: it is switched on, and no backup has been
/// saved in the last seven days (from either the button or the weekly backup).
bool weeklyBackupDue({required bool enabled, required int lastAtMillis, required DateTime now}) {
  if (!enabled) return false;
  if (lastAtMillis <= 0) return true;
  final last = DateTime.fromMillisecondsSinceEpoch(lastAtMillis);
  // A clock set back before the last backup must not stop backups for ever.
  if (last.isAfter(now)) return true;
  return now.difference(last) >= weeklyBackupEvery;
}

/// The folder picked for the weekly backup, held while the app runs. The system does not
/// let the app keep it across a restart, so it starts empty each time.
class WeeklyFolder extends Notifier<BackupFolder?> {
  @override
  BackupFolder? build() => null;

  void set(BackupFolder? folder) => state = folder;
}

final weeklyFolderProvider = NotifierProvider<WeeklyFolder, BackupFolder?>(WeeklyFolder.new);

/// What the weekly backup did at start-up.
enum WeeklyOutcome { notDue, saved, needsFolder, failed }

/// The start-up check: when the weekly backup is due, writes it to this run's folder, or
/// says the folder must be picked again. Nothing here asks the person; [askForFolder] is
/// called for that, and does the backup itself when they agree.
///
/// A protected weekly backup needs its password each time (it is never stored), so that
/// one is always handed to [askForFolder] as well.
Future<WeeklyOutcome> runWeeklyBackupAtStart(
  ProviderContainer container, {
  Future<void> Function()? askForFolder,
}) async {
  try {
    final settings = container.read(settingsRepositoryProvider);
    final due = weeklyBackupDue(
      enabled: await settings.read(BackupKeys.weekly),
      lastAtMillis: await settings.read(BackupKeys.lastAt),
      now: clock.now(),
    );
    if (!due) return WeeklyOutcome.notDue;
    final folder = container.read(weeklyFolderProvider);
    final protect = await settings.read(BackupKeys.protect);
    if (folder == null || protect) {
      await askForFolder?.call();
      return WeeklyOutcome.needsFolder;
    }
    final service = container.read(backupServiceProvider);
    final bytes = await service.createFile();
    await container
        .read(backupFilesProvider)
        .saveInto(folder, bytes, BackupService.fileNameFor(clock.now()));
    await service.recordSaved();
    return WeeklyOutcome.saved;
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo weekly backup'),
    );
    return WeeklyOutcome.failed;
  }
}

/// The weekly check as the app runs it: at start and each time the app comes back to the
/// front. It asks the person at most once while the app runs, so "Not now" holds until
/// Akatabo is next opened, and returning from a file or folder picker does not ask again.
class WeeklyBackupChecks {
  WeeklyBackupChecks(this.container, {required this.ask});

  final ProviderContainer container;
  final Future<void> Function() ask;
  bool _running = false;
  bool _asked = false;

  /// Null when a check is already running.
  Future<WeeklyOutcome?> check() async {
    if (_running) return null;
    _running = true;
    try {
      return await runWeeklyBackupAtStart(container, askForFolder: _askOnce);
    } finally {
      _running = false;
    }
  }

  Future<void> _askOnce() async {
    if (_asked) return;
    _asked = true;
    await ask();
  }
}
