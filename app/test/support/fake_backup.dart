import 'dart:typed_data';

import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/key_derivation.dart';

/// Records what the backup screens save and hands them the file the test chose.
class FakeBackupFiles implements BackupFiles {
  FakeBackupFiles({this.toPick, this.folder, this.saveAnswer = true});

  /// The file "chosen" in the open dialog; null acts as a cancel.
  PickedFile? toPick;

  /// The folder "picked"; null acts as a cancel.
  BackupFolder? folder;
  bool saveAnswer;
  bool failSaveInto = false;
  bool failPickFolder = false;

  final saved = <({String name, Uint8List bytes})>[];
  final savedInto = <({BackupFolder folder, String name, Uint8List bytes})>[];
  int picks = 0;
  int folderPicks = 0;

  /// Runs while the save dialog is "open", such as the app going out of sight.
  void Function()? whileSaving;

  @override
  Future<bool> save(Uint8List bytes, String name) async {
    whileSaving?.call();
    if (saveAnswer) saved.add((name: name, bytes: bytes));
    return saveAnswer;
  }

  @override
  Future<PickedFile?> pick() async {
    picks++;
    return toPick;
  }

  @override
  Future<BackupFolder?> pickFolder() async {
    folderPicks++;
    if (failPickFolder) throw StateError('no folder picker');
    return folder;
  }

  @override
  Future<void> saveInto(BackupFolder folder, Uint8List bytes, String name) async {
    if (failSaveInto) throw StateError('folder gone');
    savedInto.add((folder: folder, name: name, bytes: bytes));
  }
}

class FakeFolder implements BackupFolder {}

/// A key from the password and salt with no real work, so tests run fast. Real Argon2id and
/// PBKDF2 are tested on their own.
List<int> fakeKey(String password, KdfParams p) => List<int>.generate(
  32,
  (i) =>
      (password.codeUnits.fold<int>(i * 7 + 1, (a, b) => (a * 31 + b) & 0xffff) +
          p.salt[i % p.salt.length]) &
      0xff,
);

/// A [KeyDeriver] that uses [fakeKey], counting how often it is asked.
class CountingKeys {
  int tries = 0;
  int full = 0;

  /// When true, Argon2id "takes longer than the budget".
  bool argonSlow = false;

  late final KeyDeriver deriver = KeyDeriver(
    tryWithin: (password, p, deadline) async {
      tries++;
      return argonSlow ? null : fakeKey(password, p);
    },
    deriveFully: (password, p) async {
      full++;
      return fakeKey(password, p);
    },
  );
}
