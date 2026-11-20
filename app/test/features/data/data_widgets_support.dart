import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/backup_seed.dart';
import '../../support/fake_backup.dart';

/// Pumps [child] with an in-memory database, fixed settings and fake file dialogs.
Future<void> pumpData(
  WidgetTester tester,
  Widget child, {
  required AppDatabase db,
  required FakeBackupFiles files,
  Map<String, String> settings = const {},
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        backupFilesProvider.overrideWithValue(files),
        backupServiceProvider.overrideWithValue(testBackupService(db)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets database and file work finish on the real clock, then redraws.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder switchLabelled(String label) =>
    find.byWidgetPredicate((w) => w is AkSwitch && w.label == label, description: label);
