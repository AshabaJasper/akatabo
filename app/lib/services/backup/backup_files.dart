import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_codec.dart';

/// A file the person chose to restore from.
typedef PickedFile = ({String name, Uint8List bytes});

/// A folder the person picked for the weekly backup. Opaque: only [BackupFiles] reads it.
abstract interface class BackupFolder {}

/// The system's own save, open and folder dialogs. No storage permission is needed: the
/// person picks the place each time. Screens use this interface, so tests use a fake.
abstract interface class BackupFiles {
  /// Lets the person save [bytes] as [name] where they choose. False when they cancel.
  Future<bool> save(Uint8List bytes, String name);

  /// Lets the person choose a file to restore from. Null when they cancel.
  Future<PickedFile?> pick();

  /// Lets the person pick a folder for the weekly backup. Null when they cancel or the
  /// phone cannot pick folders.
  Future<BackupFolder?> pickFolder();

  /// Writes [bytes] as [name] into [folder]. Throws when the folder can no longer be used.
  Future<void> saveInto(BackupFolder folder, Uint8List bytes, String name);
}

final backupFilesProvider = Provider<BackupFiles>((ref) => FileDialogBackupFiles());

/// The largest file restore reads. Years of entries make a backup of a few megabytes.
const maxBackupFileBytes = 64 * 1024 * 1024;

/// Reads a chosen file, but only once its first bytes show it is an Akatabo backup and it is
/// not too large, so a video picked by mistake is never loaded into memory. Throws
/// [BackupException] with [BackupProblem.notAkatabo] otherwise.
Future<Uint8List> readBackupFile(File file, {int maxBytes = maxBackupFileBytes}) async {
  final magic = utf8.encode('${BackupFormat.magic}\n');
  final reader = await file.open();
  final List<int> start;
  final int length;
  try {
    length = await reader.length();
    start = await reader.read(magic.length);
  } finally {
    await reader.close();
  }
  // A file cut short inside the marker is left to the codec, which calls it damaged.
  for (var i = 0; i < start.length; i++) {
    if (start[i] != magic[i]) throw const BackupException(BackupProblem.notAkatabo);
  }
  if (length > maxBytes) throw const BackupException(BackupProblem.notAkatabo);
  return file.readAsBytes();
}

class _DialogFolder implements BackupFolder {
  _DialogFolder(this.location);
  final DirectoryLocation location;
}

/// [BackupFiles] on `flutter_file_dialog`.
///
/// The picked folder is held for as long as the app runs. The plugin gives no way to keep
/// the folder's access across a restart, so the weekly backup asks for it again after one
/// (PLAN.md, "Open points").
class FileDialogBackupFiles implements BackupFiles {
  static const _mime = 'application/octet-stream';

  @override
  Future<bool> save(Uint8List bytes, String name) async {
    final path = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(data: bytes, fileName: name, mimeTypesFilter: const [_mime]),
    );
    return path != null;
  }

  @override
  Future<PickedFile?> pick() async {
    // Any type is allowed: a file shared through a chat app often loses its extension.
    final path = await FlutterFileDialog.pickFile();
    if (path == null) return null;
    final file = File(path);
    try {
      final bytes = await readBackupFile(file);
      return (name: path.split(Platform.pathSeparator).last, bytes: bytes);
    } finally {
      // The plugin copies the file into the app's cache; it is not kept there.
      try {
        await file.delete();
      } on FileSystemException {
        // Left for the system to clear with the rest of the cache.
      }
    }
  }

  @override
  Future<BackupFolder?> pickFolder() async {
    if (!await FlutterFileDialog.isPickDirectorySupported()) return null;
    final location = await FlutterFileDialog.pickDirectory();
    return location == null ? null : _DialogFolder(location);
  }

  @override
  Future<void> saveInto(BackupFolder folder, Uint8List bytes, String name) async {
    await FlutterFileDialog.saveFileToDirectory(
      directory: (folder as _DialogFolder).location,
      data: bytes,
      fileName: name,
      mimeType: _mime,
    );
  }
}
