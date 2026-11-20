import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/settings/smart_settings_screen.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:akatabo/services/notifications/reminder_scheduler.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';

/// Records what the screen asks of the notifications, and answers the permission request.
class _FakeNotifications implements NotificationsService {
  _FakeNotifications({this.allow = true, this.allowedNow = true});
  bool allow;
  bool allowedNow;

  @override
  Future<bool> areAllowed() async => allowedNow;
  int asks = 0;
  List<PlannedReminder>? scheduled;
  int replaces = 0;

  @override
  Future<bool> requestPermission() async {
    asks++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    replaces++;
    scheduled = reminders;
  }
}

/// The drawn state: every switch on, Balanced, 80%, 20:00, Sunday evening.
final _drawn = {
  SettingKeys.dailyReminder.name: '1',
  SettingKeys.regularReminder.name: '1',
  SettingKeys.weeklySummary.name: '1',
};

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  _FakeNotifications fake, {
  Map<String, String> settings = const {},
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 3000),
  double textScale = 1,
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
        notificationsServiceProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SmartSettingsScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Lets database work finish on the real clock, then redraws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<String?> _stored(WidgetTester tester, AppDatabase db, String key) =>
    tester.runAsync<String?>(
      () async => (await (db.select(
        db.settings,
      )..where((s) => s.key.equals(key))).getSingleOrNull())?.value,
    );

Finder _switch(String label) =>
    find.byWidgetPredicate((w) => w is AkSwitch && w.label == label, description: label);

void main() {
  group('Smart help page', () {
    testWidgets('shows the drawn rows and the defaults', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      for (final text in [
        'Smart help',
        'Akatabo learns from your own entries, on this phone only. Switch off anything you '
            'do not want.',
        'WHAT IT DOES FOR YOU',
        'Suggest a category',
        'From the words you type when you add',
        'Forecast the month',
        'Where your spending is heading by month end',
        'Point out unusual payments',
        'Much larger, or at an odd time for you',
        'How often it points them out',
        'Notice regular payments',
        'Such as Yaka, data bundles and rent',
        'Forget everything it has learned',
        'REMINDERS',
        'Remind me to add each day',
        '20:00',
        'Warn me when a budget reaches',
        'Tell me before a regular payment',
        'Weekly summary',
        'Sunday evening',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final label in ['Rarely', 'Balanced', 'Often', '70%', '80%', '90%', 'Never']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Smart help starts on; reminders start off until permission is given.
      expect(tester.widget<AkSwitch>(_switch('Suggest a category')).value, isTrue);
      expect(tester.widget<AkSwitch>(_switch('Remind me to add each day')).value, isFalse);
    });

    testWidgets('a Smart help switch saves without asking for notifications', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake);

      await tester.tap(_switch('Suggest a category'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.suggestCategory.name), '0');

      await tester.tap(find.text('Often'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.unusualHowOften.name), 'often');
      expect(fake.asks, 0);
      expect(fake.replaces, 0);
    });

    testWidgets('switching a reminder on asks once, saves it and schedules it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake);

      await tester.tap(_switch('Remind me to add each day'));
      await _settle(tester);

      expect(fake.asks, 1);
      expect(await _stored(tester, db, SettingKeys.dailyReminder.name), '1');
      expect(fake.scheduled, isNotNull);
      final daily = fake.scheduled!.whereType<DailyReminder>().single;
      expect((daily.hour, daily.minute), (20, 0));
    });

    testWidgets('a refused permission keeps the switch off and says why', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications(allow: false);
      await _pump(tester, db, fake);

      await tester.tap(_switch('Weekly summary'));
      await _settle(tester);

      expect(fake.asks, 1);
      expect(await _stored(tester, db, SettingKeys.weeklySummary.name), isNull);
      expect(tester.widget<AkSwitch>(_switch('Weekly summary')).value, isFalse);
      expect(find.text(notificationsRefusedMessage), findsOneWidget);
      expect(fake.replaces, 0);
    });

    testWidgets('a reminder that is on says so when the phone blocks notifications', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(allowedNow: false), settings: _drawn);
      expect(find.text(notificationsBlockedMessage), findsOneWidget);
    });

    testWidgets('with every reminder off there is nothing to warn about', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(allowedNow: false));
      expect(find.text(notificationsBlockedMessage), findsNothing);
    });

    testWidgets('switching a reminder off does not ask and clears it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, settings: _drawn);

      await tester.tap(_switch('Tell me before a regular payment'));
      await _settle(tester);

      expect(fake.asks, 0);
      expect(await _stored(tester, db, SettingKeys.regularReminder.name), '0');
      expect(fake.replaces, 1);
      expect(fake.scheduled!.whereType<OnceReminder>(), isEmpty);
    });

    testWidgets('a budget warning level is saved', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      await tester.tap(find.text('Never'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.budgetWarnAt.name), '0');
    });

    testWidgets('the weekly summary day is chosen from the week', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake);

      await tester.tap(find.text('Sunday evening'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Send the weekly summary on'), findsOneWidget);
      await tester.tap(find.text('Friday evening'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.weeklySummaryDay.name), '5');
      expect(fake.replaces, 1, reason: 'a reminder setting reschedules');
    });

    testWidgets('the time picker saves the chosen time', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      await tester.tap(find.text('20:00'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me at'), findsOneWidget);
      // Type the time rather than dragging the dial.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '07');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.dailyReminderAt.name), '${7 * 60 + 30}');
    });

    testWidgets('forgetting asks first, then stores when it happened', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      await tester.tap(find.text('Forget everything it has learned'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.learningResetAt.name), isNull);

      await tester.tap(find.text('Forget everything it has learned'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Forget'));
      await _settle(tester);
      final stored = int.parse((await _stored(tester, db, SettingKeys.learningResetAt.name))!);
      expect(stored, greaterThan(0));
      expect(find.text(forgotMessage), findsOneWidget);
    });

    testWidgets('opened from the Reminders row, it starts at Reminders', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
            notificationsServiceProvider.overrideWithValue(_FakeNotifications()),
          ],
          child: MaterialApp(
            theme: buildAkTheme(Brightness.light, const AkAppearance()),
            home: const SmartSettingsScreen(openAtReminders: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // Scrolled as far as the list goes: the whole Reminders card is on screen.
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      expect(tester.getBottomLeft(find.text('Sunday evening')).dy, lessThan(844));
      expect(tester.getTopLeft(find.text('REMINDERS')).dy, greaterThan(0));
      expect(Routes.settingsReminders, startsWith(Routes.settingsSmart));
    });

    testWidgets('large text on a small phone does not overflow', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        _FakeNotifications(),
        settings: _drawn,
        size: const Size(320, 4000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sunday evening'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('smart help golden, ${b.name}', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _pump(
          tester,
          db,
          _FakeNotifications(),
          settings: _drawn,
          brightness: b,
          size: const Size(390, 844),
        );
        await expectLater(
          find.byType(SmartSettingsScreen),
          matchesGoldenFile('goldens/smart_help_${b.name}.png'),
        );
        // The Reminders card sits below the fold at 844px.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(
          find.byType(SmartSettingsScreen),
          matchesGoldenFile('goldens/smart_help_reminders_${b.name}.png'),
        );
      });
    }
  });

  group('rescheduling', () {
    test('reads the stored settings and the last 7 days of money out', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final fake = _FakeNotifications();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final repo = container.read(settingsRepositoryProvider);
      await repo.write(SettingKeys.weeklySummary, true);
      await repo.write(SettingKeys.dailyReminder, true);
      await repo.write(SettingKeys.dailyReminderAt, 8 * 60);
      await db
          .into(db.transactions)
          .insert(txRow(id: 'a', amount: 30000, fee: 500, at: DateTime(2026, 11, 18, 9)));
      await db
          .into(db.transactions)
          .insert(txRow(id: 'b', amount: 20000, at: DateTime(2026, 11, 13, 9)));
      // Eight days back: outside the week.
      await db
          .into(db.transactions)
          .insert(txRow(id: 'c', amount: 99000, at: DateTime(2026, 11, 12, 9)));

      await withClock(
        Clock.fixed(DateTime(2026, 11, 19, 10)),
        () => container.read(reminderSchedulerProvider).sync(),
      );

      final plan = fake.scheduled!;
      expect(plan.whereType<DailyReminder>().single.hour, 8);
      expect(plan.whereType<WeeklyReminder>().single.body, contains('UGX 50,500'));
    });

    test('at start, and again when the regular payments change', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final fake = _FakeNotifications();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await container.read(settingsRepositoryProvider).write(SettingKeys.regularReminder, true);

      await rescheduleRemindersAtStart(container);
      expect(fake.replaces, 1);
      expect(fake.scheduled, isEmpty);

      final due = DateTime.now().add(const Duration(days: 5));
      await RegularPaymentRepository(db).add(
        label: 'Rent',
        amount: 300000,
        intervalDays: 30,
        nextDueOn: due.year * 10000 + due.month * 100 + due.day,
      );
      for (var i = 0; i < 100 && fake.replaces < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(fake.replaces, 2);
      expect(fake.scheduled!.single.title, 'Rent is due tomorrow');
    });

    test('a failed reschedule does not block the next one', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final fake = _ThrowOnce();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final scheduler = container.read(reminderSchedulerProvider);
      await expectLater(scheduler.sync(), throwsStateError);
      await scheduler.sync();
      expect(fake.calls, 2);
    });
  });
}

class _ThrowOnce implements NotificationsService {
  int calls = 0;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> areAllowed() async => true;
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    calls++;
    if (calls == 1) throw StateError('plugin failed');
  }
}
