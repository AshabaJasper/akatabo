import 'dart:convert';
import 'dart:io';

import 'package:akatabo/services/backup/backup_codec.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('akatabo-files-'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<File> file(String name, List<int> bytes) => File('${dir.path}/$name').writeAsBytes(bytes);

  Matcher problem(BackupProblem p) =>
      throwsA(isA<BackupException>().having((e) => e.problem, 'problem', p));

  test('reads a file that starts like a backup', () async {
    final bytes = utf8.encode('AKATABO-BACKUP\n{}\nsha256:00\n');
    expect(await readBackupFile(await file('b.akatabo', bytes)), bytes);
  });

  test('refuses a file that does not start like a backup, before reading it all', () async {
    final video = await file('clip.mp4', [0, 0, 0, 0x18, ...utf8.encode('ftypmp42'), 1, 2, 3]);
    await expectLater(readBackupFile(video), problem(BackupProblem.notAkatabo));
  });

  test('refuses a file larger than any backup could be', () async {
    final huge = await file('big.akatabo', [
      ...utf8.encode('AKATABO-BACKUP\n'),
      ...List.filled(2048, 0x61),
    ]);
    await expectLater(readBackupFile(huge, maxBytes: 1024), problem(BackupProblem.notAkatabo));
  });

  test('leaves a file cut short inside the marker to the codec', () async {
    final cut = await file('cut.akatabo', utf8.encode('AKATA'));
    expect(await readBackupFile(cut), utf8.encode('AKATA'));
  });
}
