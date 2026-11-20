import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import 'backup_codec.dart';
import 'backup_settings.dart';
import 'backup_store.dart';
import 'key_derivation.dart';
import 'restore_planner.dart';

/// The app's version as the About row shows it, written into each backup's header.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// One key maker for the app's lifetime, so a slow Argon2id is found out only once.
final keyDeriverProvider = Provider<KeyDeriver>((ref) => KeyDeriver());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(appDatabaseProvider),
    keys: ref.watch(keyDeriverProvider),
    appVersion: () => ref.read(appVersionProvider.future),
  ),
);

/// A backup file that has been read and checked, with what restoring it would do.
class OpenedBackup {
  const OpenedBackup({required this.header, required this.tables, required this.preview});
  final BackupHeader header;
  final BackupTables tables;
  final RestorePreview preview;
}

/// Saving a backup file, reading one, and restoring it.
class BackupService {
  BackupService(this.db, {required KeyDeriver keys, required this.appVersion})
    : codec = BackupCodec(schemaVersion: db.schemaVersion, keys: keys),
      store = BackupStore(db);

  final AppDatabase db;
  final BackupCodec codec;
  final BackupStore store;
  final Future<String> Function() appVersion;

  /// `akatabo-backup-2026-11-19.akatabo`.
  static String fileNameFor(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'akatabo-backup-${now.year}-${two(now.month)}-${two(now.day)}'
        '.${BackupFormat.extension}';
  }

  /// The whole backup of this phone as file bytes.
  Future<Uint8List> createFile({String? password}) async {
    final tables = await store.readAll();
    return codec.encode(
      tables,
      appVersion: await appVersion(),
      now: clock.now(),
      password: password,
    );
  }

  /// Notes that a backup was saved just now.
  Future<void> recordSaved() =>
      SettingsRepository(db).write(BackupKeys.lastAt, clock.now().millisecondsSinceEpoch);

  /// Reads [bytes] and compares them with this phone. Throws [BackupException].
  Future<OpenedBackup> open(Uint8List bytes, {String? password}) async {
    final header = codec.readHeader(bytes);
    final tables = await codec.decode(bytes, password: password);
    BackupStore.checkRows(tables);
    return OpenedBackup(header: header, tables: tables, preview: await previewOf(tables));
  }

  Future<RestorePreview> previewOf(BackupTables tables) async => RestorePlanner(
    backup: tables,
    phone: await store.readAll(),
    keepOnPhone: isLocalOnlySetting,
  ).preview();

  /// Restores [backup] the chosen way, in one database transaction. The phone is read again
  /// at this moment, so an entry added since the preview is treated correctly.
  Future<void> restore(OpenedBackup backup, RestoreMode mode) async {
    final plan = RestorePlanner(
      backup: backup.tables,
      phone: await store.readAll(),
      keepOnPhone: isLocalOnlySetting,
    ).plan(mode);
    await store.apply(plan);
  }
}
