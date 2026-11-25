// Draws the README and store screenshots from the real app, with made-up entries.
//
// Skipped unless AKATABO_SCREENSHOTS=1, so a normal `flutter test` and CI never write files.
// Run from app/ on Windows (fonts render as in the goldens):
//
//   $env:AKATABO_SCREENSHOTS = '1'; flutter test test/screenshots
//
// Images go to ../docs/screenshots/. Nothing here reads or writes a phone's data: the app runs
// on an in-memory database filled with the demo entries from lib/data/seed/demo_seed.dart.
import 'dart:io';
import 'dart:math' as math;

import 'package:akatabo/app/app.dart';
import 'package:akatabo/app/bootstrap.dart';
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/data/seed/demo_seed.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

import '../support/fake_notifications.dart';
import '../support/fake_security.dart';

final _on = Platform.environment['AKATABO_SCREENSHOTS'] == '1';

/// A Thursday evening late in the month, so the month has a story to tell.
final _now = DateTime(2026, 11, 26, 18, 40);

const _outDir = '../docs/screenshots';
const _storeDir = '../fastlane/metadata/android/en-US/images';

/// The shots the store listings show, in their order there.
const _storeOrder = [
  'phone-home-light',
  'phone-insights-light',
  'phone-forecast-dark',
  'phone-goals-light',
  'phone-add-dark',
  'phone-calendar-light',
  'tablet-home-light',
  'tablet-insights-dark',
];

/// A phone, 412dp wide like most Android phones. The height makes it exactly 2:1, the tallest
/// shape Google Play accepts for a screenshot.
const _phone = Size(412, 824);

/// A tablet in landscape.
const _tablet = Size(1280, 800);

Future<AppDatabase> _demoDatabase({required bool dark}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final settings = SettingsRepository(db);
  await settings.write(SettingKeys.onboardingDone, true);
  await settings.write(SettingKeys.theme, dark ? ThemeMode.dark : ThemeMode.light);
  await withClock(Clock.fixed(_now), () async {
    await insertDemoData(TransactionRepository(db), now: _now, isEmpty: true);
    final categories = CategoryRepository(db);
    await categories.setBudget(
      DefaultIds.food,
      monthlyBudget: 600000,
      carriesOver: false,
      warnAt: 80,
    );
    await categories.setBudget(
      DefaultIds.transport,
      monthlyBudget: 200000,
      carriesOver: false,
      warnAt: 80,
    );
    await categories.setBudget(
      DefaultIds.bills,
      monthlyBudget: 250000,
      carriesOver: true,
      warnAt: 80,
    );
    final goals = GoalRepository(db);
    final laptop = await goals.add(
      name: 'New laptop',
      target: 3500000,
      colourToken: 'cat-blue',
      targetDay: 20270630,
    );
    await goals.addMove(goalId: laptop, accountId: DefaultIds.bank, amount: 1200000);
    final school = await goals.add(
      name: 'School fees, term one',
      target: 1800000,
      colourToken: 'cat-green',
    );
    await goals.addMove(goalId: school, accountId: DefaultIds.mtn, amount: 1350000);
    await RegularPaymentRepository(db).add(
      label: 'Rent',
      amount: 450000,
      intervalDays: 30,
      nextDueOn: 20261201,
      categoryId: DefaultIds.bills,
    );
  });
  return db;
}

class _Shot {
  _Shot(this.tester, this.boundary);
  final WidgetTester tester;
  final GlobalKey boundary;

  /// Lets the database streams deliver, then waits for animations to finish.
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> save(String name) async {
    await settle();
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: tester.view.devicePixelRatio);
      // Google Play takes JPEG or 24-bit PNG with no alpha, at most twice as long as wide.
      expect(
        math.max(image.width, image.height),
        lessThanOrEqualTo(2 * math.min(image.width, image.height)),
        reason: '$name is longer than 2:1',
      );
      final raw = await image.toByteData();
      final rgb = img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: raw!.buffer,
        numChannels: 4,
      ).convert(numChannels: 3);
      expect(rgb.numChannels, 3, reason: '$name must have no alpha');
      final png = img.encodePng(rgb);
      File('$_outDir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png);
      // The store listings (F-Droid, IzzyOnDroid) take numbered copies in a fixed order.
      final store = _storeOrder.indexOf(name);
      if (store >= 0) {
        final folder = name.startsWith('tablet-') ? 'tenInchScreenshots' : 'phoneScreenshots';
        final number = _storeOrder.where((n) => n.startsWith(name.split('-').first)).toList();
        File('$_storeDir/$folder/${number.indexOf(name) + 1}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png);
      }
    });
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle();
  }
}

Future<_Shot> _start(WidgetTester tester, {required Size size, required bool dark}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final db = (await tester.runAsync(() => _demoDatabase(dark: dark)))!;
  final container = (await tester.runAsync(
    () => createAppContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appNowProvider.overrideWithValue(_now),
        notificationsServiceProvider.overrideWithValue(FakeNotifications()),
        ...securityOverrides(values: MapSecureValues()),
      ],
    ),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.runAsync(db.close);
  });

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: UncontrolledProviderScope(
        container: container,
        child: const AkataboApp(onboardingDone: true, opensOn: AppOpensOn.home),
      ),
    ),
  );
  final shot = _Shot(tester, key);
  await shot.settle();
  return shot;
}

/// Opens the app, goes to a screen with [go] and saves it as [name]. [shows] is text only
/// that screen has, so a tap that misses fails here instead of saving the wrong screen.
void _shot(
  String name, {
  required Size size,
  required bool dark,
  required Finder shows,
  Future<void> Function(_Shot s)? go,
}) {
  testWidgets(name, skip: !_on, (tester) async {
    await withClock(Clock.fixed(_now), () async {
      final s = await _start(tester, size: size, dark: dark);
      if (go != null) await go(s);
      expect(shows, findsWidgets, reason: '$name did not reach its screen');
      await s.save(name);
    });
  });
}

Future<void> _tab(_Shot s, String label) => s.tap(find.text(label));

final _home = find.text('Where it went');
final _insights = find.text('Spent, 1 to 26 November');

void main() {
  _shot('phone-home-light', size: _phone, dark: false, shows: _home);
  _shot('phone-home-dark', size: _phone, dark: true, shows: _home);
  _shot(
    'phone-insights-light',
    size: _phone,
    dark: false,
    shows: _insights,
    go: (s) => _tab(s, 'Insights'),
  );
  _shot(
    'phone-forecast-dark',
    size: _phone,
    dark: true,
    shows: find.textContaining('Forecast: money out by'),
    go: (s) => s.tap(find.textContaining('Heading for')),
  );
  _shot(
    'phone-goals-light',
    size: _phone,
    dark: false,
    shows: find.text('Saving now'),
    go: (s) => _tab(s, 'Goals'),
  );
  _shot(
    'phone-add-dark',
    size: _phone,
    dark: true,
    shows: find.text('Move money'),
    go: (s) => s.tap(find.bySemanticsLabel('Add a transaction')),
  );
  _shot(
    'phone-calendar-light',
    size: _phone,
    dark: false,
    shows: find.text('November 2026'),
    go: (s) => _tab(s, 'November'),
  );
  _shot('tablet-home-light', size: _tablet, dark: false, shows: find.text('Latest'));
  _shot(
    'tablet-insights-dark',
    size: _tablet,
    dark: true,
    shows: _insights,
    go: (s) => _tab(s, 'Insights'),
  );
}
