import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/forecast/forecast_providers.dart';
import 'package:akatabo/features/regular/regular_providers.dart';
import 'package:akatabo/features/settings/reminders_screen.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:akatabo/features/settings/smart_help_screen.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:akatabo/services/notifications/reminder_scheduler.dart';
import 'package:akatabo/services/notifications/reminder_switch.dart';
import 'package:akatabo/services/permissions/phone_permissions.dart';
import 'package:akatabo/smart/forecast/forecast_range.dart';
import 'package:akatabo/widgets/ak_controls.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_notifications.dart';
import '../../support/fixtures.dart';

typedef _FakeNotifications = FakeNotifications;

/// Records each phone settings page opened.
class _FakePhone implements PhonePermissions {
  final opened = <PhoneSettingsPage>[];

  @override
  Future<Map<String, bool>?> requested() async => const {};

  @override
  Future<bool> open(PhoneSettingsPage page) async {
    opened.add(page);
    return true;
  }
}

/// The drawn state: every reminder on, Balanced, 20:00, Sunday evening.
final _drawn = {
  SettingKeys.dailyReminder.name: '1',
  SettingKeys.budgetWarn.name: '1',
  SettingKeys.regularReminder.name: '1',
  SettingKeys.weeklySummary.name: '1',
};

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  _FakeNotifications fake, {
  Widget page = const SmartHelpScreen(),
  Map<String, String> settings = const {},
  List<SnapshotPoint> history = const [],
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 3000),
  double textScale = 1,
  PhonePermissions? phone,
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
        // A fixed day, as every screen test has: the real one sets a timer for midnight.
        appNowProvider.overrideWithValue(DateTime(2026, 11, 24, 10)),
        // Fixed data, as every screen test has: a live database watch keeps timers the
        // test's fake clock never runs, so closing the database would wait forever.
        forecastHistoryProvider.overrideWithValue(history),
        activeRegularProvider.overrideWith((ref) => Stream.value(const [])),
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        notificationsServiceProvider.overrideWithValue(fake),
        if (phone != null) phonePermissionsProvider.overrideWithValue(phone),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
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
  // Start-up listens for the app going to the background, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart help page', () {
    testWidgets('shows the drawn rows and the defaults', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      for (final text in [
        'Smart help',
        'Akatabo learns from your own entries, on this phone only. Switch off anything you '
            'do not want.',
        'WHAT IT HAS LEARNED',
        'Forecast accuracy',
        'No saved months yet',
        'Regular payments noticed',
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
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final label in ['Rarely', 'Balanced', 'Often']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The smart features work now; no "later update" note is left under them.
      expect(find.textContaining('later update'), findsNothing);
      expect(tester.widget<AkSwitch>(_switch('Suggest a category')).value, isTrue);
      // Reminders are not on this page any more.
      expect(find.text('Remind me to add each day'), findsNothing);
    });

    testWidgets(
      'forecast accuracy averages the saved months, leaving out one forecast at nothing',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _pump(
          tester,
          db,
          _FakeNotifications(),
          history: const [
            SnapshotPoint(periodStart: 20260801, dayInPeriod: 24, point: 100000, actual: 110000),
            SnapshotPoint(periodStart: 20260901, dayInPeriod: 24, point: 200000, actual: 180000),
            // Dividing by a forecast of nothing would crash the page.
            SnapshotPoint(periodStart: 20261001, dayInPeriod: 24, point: 0, actual: 5000),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Within about 10%'), findsOneWidget);
      },
    );

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

    testWidgets("open notification settings goes to Akatabo's page in the phone", (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final phone = _FakePhone();
      await _pump(
        tester,
        db,
        _FakeNotifications(allowedNow: false),
        page: const RemindersScreen(),
        phone: phone,
      );

      await tester.tap(find.text('Open notification settings'));
      await _settle(tester);

      expect(phone.opened, [PhoneSettingsPage.notifications]);
    });

    testWidgets('every row in a card starts 14 from the card edge', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications());

      final left = <String, double>{
        for (final text in [
          'Suggest a category', // noted switch row
          'How often it points them out', // segment row
          'Forget everything it has learned', // action row
        ])
          text: tester.getTopLeft(find.text(text)).dx,
      };
      // The page has 24 at the sides; the card's border is drawn inside its edge.
      for (final e in left.entries) {
        expect(e.value, AkSpace.s6 + settingsRowSide, reason: e.key);
      }
    });

    testWidgets('large text on a small phone does not overflow', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(), size: const Size(320, 4000), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Forget everything it has learned'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('smart help golden, ${b.name}', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _pump(tester, db, _FakeNotifications(), brightness: b, size: const Size(390, 844));
        await expectLater(
          find.byType(SmartHelpScreen),
          matchesGoldenFile('goldens/smart_help_${b.name}.png'),
        );
      });
    }
  });

  group('Reminders page', () {
    testWidgets('shows the drawn rows, each with its next time', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        _FakeNotifications(),
        page: const RemindersScreen(),
        settings: _drawn,
      );
      await _settle(tester);

      for (final text in [
        'Reminders',
        'A reminder is sent only when you switch it on. Each one shows when it next fires.',
        'REMINDERS',
        'Remind me to add each day',
        '20:00',
        'Warn me when a budget is nearly used',
        "At each budget's own warn level, and again if it goes over",
        'Tell me before a regular payment',
        'The morning before it is due',
        'Weekly summary',
        'Sunday evening',
        'CHECK',
        'Notifications on this phone',
        'Send a test notification',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Each switched-on reminder shows its next time, as words and a clock time.
      expect(find.textContaining('Next: '), findsNWidgets(2));
      expect(tester.widget<AkSwitch>(_switch('Remind me to add each day')).value, isTrue);
    });

    testWidgets('reminders start off, with no next time shown', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(), page: const RemindersScreen());
      await _settle(tester);

      expect(tester.widget<AkSwitch>(_switch('Remind me to add each day')).value, isFalse);
      expect(find.text('Off'), findsWidgets);
      expect(find.textContaining('Next: '), findsNothing);
    });

    testWidgets('switching a reminder on asks once, saves it and schedules it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, page: const RemindersScreen());

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
      await _pump(tester, db, fake, page: const RemindersScreen());

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
      await _pump(
        tester,
        db,
        _FakeNotifications(allowedNow: false),
        page: const RemindersScreen(),
        settings: _drawn,
      );
      await _settle(tester);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text(notificationsBlockedMessage), findsOneWidget);
    });

    testWidgets('allowing notifications in the phone settings shows when Akatabo comes back', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications(allowedNow: false);
      await _pump(tester, db, fake, page: const RemindersScreen(), settings: _drawn);
      await _settle(tester);
      expect(find.text('Blocked'), findsOneWidget);

      // The person allows notifications in the phone's settings, then returns.
      fake.allowedNow = true;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      expect(find.text('Allowed'), findsOneWidget);
      expect(find.text(notificationsBlockedMessage), findsNothing);
    });

    testWidgets('with every reminder off there is nothing to warn about', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(allowedNow: false), page: const RemindersScreen());
      await _settle(tester);
      expect(find.text(notificationsBlockedMessage), findsNothing);
    });

    testWidgets('switching a reminder off does not ask and clears it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, page: const RemindersScreen(), settings: _drawn);

      await tester.tap(_switch('Tell me before a regular payment'));
      await _settle(tester);

      expect(fake.asks, 0);
      expect(await _stored(tester, db, SettingKeys.regularReminder.name), '0');
      expect(fake.replaces, 1);
      expect(fake.scheduled!.whereType<OnceReminder>(), isEmpty);
    });

    testWidgets('the budget warning is a reminder switch: it asks first, then saves', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, page: const RemindersScreen());

      await tester.tap(_switch('Warn me when a budget is nearly used'));
      await _settle(tester);
      expect(fake.asks, 1);
      expect(await _stored(tester, db, SettingKeys.budgetWarn.name), '1');
    });

    testWidgets('the budget warning stays off when notifications are refused', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications(allow: false);
      await _pump(tester, db, fake, page: const RemindersScreen());

      await tester.tap(_switch('Warn me when a budget is nearly used'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.budgetWarn.name), isNull);
      expect(find.text(notificationsRefusedMessage), findsOneWidget);
    });

    testWidgets('the weekly summary day is chosen from the week, current day ticked', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, page: const RemindersScreen());

      await tester.tap(find.text('Sunday evening'));
      await tester.pumpAndSettle();
      expect(find.text('Send the weekly summary on'), findsOneWidget);
      // The shared choice sheet, with the stored day selected.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sunday evening').last),
        matchesSemantics(
          label: 'Sunday evening',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Friday evening'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.weeklySummaryDay.name), '5');
      expect(fake.replaces, 1, reason: 'a reminder setting reschedules');
    });

    testWidgets('the time picker saves the chosen time', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(), page: const RemindersScreen());

      await tester.tap(find.text('20:00'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me at'), findsOneWidget);
      // The time is typed: the dialog opens with an hour field and a minute field.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '07');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await _settle(tester);
      expect(await _stored(tester, db, SettingKeys.dailyReminderAt.name), '${7 * 60 + 30}');
    });

    testWidgets('the test notification is sent now, when the phone allows it', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications();
      await _pump(tester, db, fake, page: const RemindersScreen());

      await tester.tap(find.text('Send a test notification'));
      await _settle(tester);

      expect(fake.shown, hasLength(1));
      expect(fake.shown.single.title, 'Akatabo');
      expect(find.text('Sent. It should appear at the top of your phone.'), findsOneWidget);
    });

    testWidgets('the test notification says why it cannot be sent when blocked', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = _FakeNotifications(allowedNow: false);
      await _pump(tester, db, fake, page: const RemindersScreen());

      await tester.tap(find.text('Send a test notification'));
      await _settle(tester);

      expect(fake.shown, isEmpty);
      expect(find.text(notificationsBlockedMessage), findsOneWidget);
    });

    testWidgets('every row in a card starts 14 from the card edge', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(tester, db, _FakeNotifications(), page: const RemindersScreen());

      final left = <String, double>{
        for (final text in [
          'Remind me to add each day', // noted switch row
          'At', // shared value row
          'Send a test notification', // action row
        ])
          text: tester.getTopLeft(find.text(text)).dx,
      };
      for (final e in left.entries) {
        expect(e.value, AkSpace.s6 + settingsRowSide, reason: e.key);
      }
    });

    testWidgets('large text on a small phone does not overflow', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _pump(
        tester,
        db,
        _FakeNotifications(),
        page: const RemindersScreen(),
        settings: _drawn,
        size: const Size(320, 4000),
        textScale: 2,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Sunday evening'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('reminders golden, ${b.name}', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        // A fixed time of day: "Next: tonight" would read "tomorrow" after 20:00.
        await withClock(Clock.fixed(DateTime(2026, 11, 24, 10)), () async {
          await _pump(
            tester,
            db,
            _FakeNotifications(),
            page: const RemindersScreen(),
            settings: _drawn,
            brightness: b,
            size: const Size(390, 844),
          );
          await _settle(tester);
          await expectLater(
            find.byType(RemindersScreen),
            matchesGoldenFile('goldens/reminders_${b.name}.png'),
          );
          // The Check card sits below the fold at 844px.
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pump(const Duration(milliseconds: 500));
          await expectLater(
            find.byType(RemindersScreen),
            matchesGoldenFile('goldens/reminders_check_${b.name}.png'),
          );
        });
      });
    }
  });

  group('Reminder times', () {
    // Tuesday 24 November 2026, 10:00.
    final now = DateTime(2026, 11, 24, 10);

    test('a daily time later today is today', () {
      expect(nextReminderAt(now, hour: 20, minute: 0), DateTime(2026, 11, 24, 20));
    });

    test('a daily time already passed is tomorrow, and so is the exact time now', () {
      expect(nextReminderAt(now, hour: 7, minute: 30), DateTime(2026, 11, 25, 7, 30));
      expect(
        nextReminderAt(DateTime(2026, 11, 24, 20), hour: 20, minute: 0),
        DateTime(2026, 11, 25, 20),
      );
    });

    test('a weekday is the next day that matches it, today when it is still to come', () {
      expect(
        nextReminderAt(now, hour: 19, minute: 0, weekday: DateTime.sunday),
        DateTime(2026, 11, 29, 19),
      );
      expect(
        nextReminderAt(now, hour: 19, minute: 0, weekday: DateTime.tuesday),
        DateTime(2026, 11, 24, 19),
      );
      expect(
        nextReminderAt(now, hour: 9, minute: 0, weekday: DateTime.tuesday),
        DateTime(2026, 12, 1, 9),
      );
    });

    test('the next time is said in words a person would use', () {
      expect(nextReminderWords(DateTime(2026, 11, 24, 20), now), 'tonight, 20:00');
      expect(
        nextReminderWords(DateTime(2026, 11, 24, 9), DateTime(2026, 11, 24, 7)),
        'today, 09:00',
      );
      expect(nextReminderWords(DateTime(2026, 11, 25, 7, 30), now), 'tomorrow, 07:30');
      expect(nextReminderWords(DateTime(2026, 11, 29, 19), now), 'Sunday, 19:00');
    });

    test('on the summary day after it was sent, the next one is "next Sunday"', () {
      final sundayEvening = DateTime(2026, 11, 29, 20);
      final next = nextReminderAt(sundayEvening, hour: 19, minute: 0, weekday: DateTime.sunday);
      expect(next, DateTime(2026, 12, 6, 19));
      expect(nextReminderWords(next, sundayEvening), 'next Sunday, 19:00');
    });
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
      expect(fake.asks, 0, reason: 'permission is never asked at start');

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

    test('going to the background works the weekly figure out again', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final db = AppDatabase(NativeDatabase.memory());
      final fake = _FakeNotifications();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsServiceProvider.overrideWithValue(fake),
        ],
      );
      // The engine reports every step, so the test does too.
      void stepTo(List<AppLifecycleState> states) =>
          states.forEach(binding.handleAppLifecycleStateChanged);
      addTearDown(() async {
        container.dispose();
        stepTo(const [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]);
        await db.close();
      });
      await container.read(settingsRepositoryProvider).write(SettingKeys.weeklySummary, true);
      final now = DateTime(2026, 11, 19, 10);

      await withClock(Clock.fixed(now), () => rescheduleRemindersAtStart(container));
      expect(fake.scheduled!.whereType<WeeklyReminder>().single.body, contains('UGX 0'));

      // Spent while the app is open, then the app goes to the background.
      await db
          .into(db.transactions)
          .insert(txRow(id: 'a', amount: 30000, at: DateTime(2026, 11, 19, 9)));
      final before = fake.replaces;
      await withClock(Clock.fixed(now), () async {
        stepTo(const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]);
        for (var i = 0; i < 100 && fake.replaces == before; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(fake.replaces, before + 1, reason: 'one sync, not one per lifecycle step');
      expect(fake.scheduled!.whereType<WeeklyReminder>().single.body, contains('UGX 30,000'));
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

  @override
  Future<void> showNow(int id, String title, String body) async {}
}
