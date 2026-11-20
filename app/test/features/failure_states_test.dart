// Phase 8 states audit: what each screen says when its data cannot be read, and when a save
// or delete fails. Every one of these used to show a blank box or nothing at all.
import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/router.dart';
import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/demo_seed.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:akatabo/services/backup/backup_files.dart';
import 'package:akatabo/services/backup/backup_service.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/widgets/ak_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../flutter_test_config.dart';
import '../support/backup_seed.dart';
import '../support/fake_backup.dart';
import '../support/fake_notifications.dart';
import '../support/fake_security.dart';

/// Entries that can never be read, as when the database file is damaged.
class _UnreadableEntries extends TransactionRepository {
  _UnreadableEntries(super.db);
  static final _broken = StateError('database cannot be read');

  @override
  Stream<List<Transaction>> watchIn(Period period) => Stream.error(_broken);
  @override
  Stream<List<Transaction>> watchLatest(int limit) => Stream.error(_broken);
  @override
  Stream<List<Transaction>> watchAll() => Stream.error(_broken);
}

/// Entries that read fine but cannot be deleted.
class _UndeletableEntries extends TransactionRepository {
  _UndeletableEntries(super.db);
  @override
  Future<void> delete(String id) => Future.error(StateError('disk full'));
}

/// Regular payments that cannot be changed.
class _StuckRegular extends RegularPaymentRepository {
  _StuckRegular(super.db);
  @override
  Future<void> dismiss(String id) => Future.error(StateError('disk full'));
}

Future<void> _open(
  WidgetTester tester,
  String location,
  AppDatabase db, {
  List<Override> extra = const [],
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  // Reported errors are expected here; the screen's own words are what is checked.
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appNowProvider.overrideWithValue(testNow),
        backupFilesProvider.overrideWithValue(FakeBackupFiles() as BackupFiles),
        backupServiceProvider.overrideWithValue(testBackupService(db)),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        notificationsServiceProvider.overrideWithValue(FakeNotifications() as NotificationsService),
        ...securityOverrides(values: MapSecureValues()),
        ...extra,
      ],
      child: AkataboApp(router: router, onboardingDone: true),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _close(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  addTearDown(db.close);
}

Future<AppDatabase> _demoDb(WidgetTester tester) async {
  final db = memoryDb();
  await tester.runAsync(
    () => insertDemoData(TransactionRepository(db), now: testNow, isEmpty: true),
  );
  return db;
}

void main() {
  group('a screen whose entries cannot be read says so', () {
    for (final (name, route) in [
      ('Home', Routes.home),
      ('Insights', Routes.insights),
      ('All transactions', Routes.transactions),
      ('Categories', Routes.categories),
      ('Fees and tax', Routes.fees),
      ('Forecast', Routes.forecast),
    ]) {
      testWidgets(name, (tester) async {
        final db = memoryDb();
        await _open(
          tester,
          route,
          db,
          extra: [transactionRepositoryProvider.overrideWithValue(_UnreadableEntries(db))],
        );
        expect(find.text(loadFailedText), findsOneWidget);
        expect(find.textContaining('UGX 0'), findsNothing, reason: 'never a false zero');
        await _close(tester, db);
      });
    }
  });

  testWidgets('a delete that fails keeps the entry open and says so', (tester) async {
    final db = await _demoDb(tester);
    late String id;
    await tester.runAsync(() async => id = (await TransactionRepository(db).listAll()).first.id);
    await _open(
      tester,
      '/transactions/$id',
      db,
      extra: [transactionRepositoryProvider.overrideWithValue(_UndeletableEntries(db))],
    );
    await tester.ensureVisible(find.bySemanticsLabel('Delete this entry'));
    await tester.tap(find.bySemanticsLabel('Delete this entry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is removed from your totals'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await _settle(tester);
    expect(find.textContaining('could not be deleted'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete this entry'), findsOneWidget, reason: 'still open');
    await tester.runAsync(() async {
      expect(await TransactionRepository(db).listAll(), isNotEmpty);
    });
    await _close(tester, db);
  });

  testWidgets('a regular payment that cannot be removed stays and says so', (tester) async {
    final db = memoryDb();
    await tester.runAsync(
      () =>
          RegularPaymentRepository(db)
              .add(label: 'Rent', amount: 400000, intervalDays: 30, nextDueOn: 20261125),
    );
    await _open(
      tester,
      Routes.regular,
      db,
      extra: [regularPaymentRepositoryProvider.overrideWithValue(_StuckRegular(db))],
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await _settle(tester);
    expect(find.text('Rent could not be removed. Try again.'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget, reason: 'the row is still listed');
    await _close(tester, db);
  });

  testWidgets('saveOrSay reports a failure and returns false', (tester) async {
    final spot = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(key: spot)),
      ),
    );
    final ctx = spot.currentContext!;
    final previous = FlutterError.onError;
    var reported = 0;
    FlutterError.onError = (_) => reported++;
    addTearDown(() => FlutterError.onError = previous);
    late bool ok;
    await tester.runAsync(() async => ok = await saveOrSay(ctx, () => Future.error('no')));
    await tester.pump();
    expect(ok, isFalse);
    expect(reported, 1);
    expect(find.text(saveFailedText), findsOneWidget);
  });
}
