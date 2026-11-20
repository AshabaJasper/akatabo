import 'dart:async';

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/features/lock/app_lock_screen.dart';
import 'package:akatabo/features/lock/pin_flow_screen.dart';
import 'package:akatabo/features/privacy/privacy_section.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:akatabo/services/security/biometrics.dart';
import 'package:akatabo/services/security/lock_controller.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_security.dart';

/// The drawn state: lock on with fingerprint, one minute, amounts shown, blank switcher.
final _drawn = {
  PrivacyKeys.lockOn.name: '1',
  PrivacyKeys.unlockWith.name: UnlockMethod.biometric.name,
};

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  MapSecureValues values, {
  Map<String, String> settings = const {},
  FakeBiometrics? biometrics,
  Brightness brightness = Brightness.light,
  List<Override> extra = const [],
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings)),
        ...securityOverrides(values: values, biometrics: biometrics),
        ...extra,
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        // App lock has its own page; both sections are pumped so each test finds its rows.
        home: const SettingsPage(
          title: 'Privacy and data',
          children: [AppLockSection(), PrivacySection()],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Lets database and secure-storage work finish on the real clock, then redraws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.bySemanticsLabel(d).last);
    await tester.pump();
  }
  await _settle(tester);
}

Future<String?> _stored(WidgetTester tester, AppDatabase db, String key) =>
    tester.runAsync<String?>(
      () async => (await (db.select(
        db.settings,
      )..where((s) => s.key.equals(key))).getSingleOrNull())?.value,
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('with no PIN, App lock offers "Set a PIN" and says what forgetting one means', (
    tester,
  ) async {
    await _pump(tester, db, MapSecureValues());
    await _settle(tester);
    expect(find.text('Set a PIN'), findsOneWidget, reason: 'always in reach, lock on or off');
    expect(find.text('Change PIN'), findsNothing);
    expect(find.textContaining('the only way back in is to delete everything'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget, reason: "Privacy's App lock row says the state");

    await tester.tap(find.text('Set a PIN'));
    await _settle(tester);
    expect(
      find.text('Choose a $pinLength-digit PIN'),
      findsOneWidget,
      reason: 'the set-a-PIN screen opened',
    );
  });

  testWidgets('a PIN left behind with the lock off is replaced, never asked for', (tester) async {
    final values = await valuesWithPin('2580');
    await _pump(tester, db, values);
    await _settle(tester);
    expect(find.text('Set a PIN'), findsOneWidget);
    expect(find.text('Change PIN'), findsNothing);
    await tester.tap(find.text('Set a PIN'));
    await _settle(tester);
    expect(find.text('Choose a $pinLength-digit PIN'), findsOneWidget);
    expect(find.text('Enter your current PIN'), findsNothing);
  });

  testWidgets('while the PIN check loads, no lock row is offered and App lock has no value', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await _pump(
      tester,
      db,
      MapSecureValues(),
      settings: {PrivacyKeys.lockOn.name: '1'},
      extra: [pinIsSetProvider.overrideWith((ref) => pending.future)],
    );
    expect(find.text('Set a PIN'), findsNothing, reason: 'it would replace the PIN unasked');
    expect(find.text('Lock the app'), findsNothing);
    expect(find.text('Off'), findsNothing);

    pending.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
  });

  testWidgets('switching the lock on sets a PIN, entered twice', (tester) async {
    final values = MapSecureValues();
    await _pump(tester, db, values);
    expect(find.text('Lock after'), findsNothing, reason: 'shown only while the lock is on');

    await tester.tap(find.bySemanticsLabel('Lock the app'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a 4-digit PIN'), findsOneWidget);
    await _type(tester, '1357');
    expect(find.text('Enter the same PIN again'), findsOneWidget);
    await _type(tester, '2468');
    expect(find.text('The two PINs did not match. Choose a PIN again.'), findsOneWidget);
    expect(values.values, isEmpty);

    await _type(tester, '1357');
    await _type(tester, '1357');
    await tester.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(await _stored(tester, db, PrivacyKeys.lockOn.name), '1');
    final hash = values.values['akatabo.pin.hash'];
    expect(hash, isNotNull);
    expect(hash, isNot(contains('1357')));
  });

  testWidgets('switching the lock off needs the current PIN', (tester) async {
    final values = await valuesWithPin('2580');
    await _pump(tester, db, values, settings: {PrivacyKeys.lockOn.name: '1'});
    await _settle(tester);
    expect(find.text('Lock after'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Lock the app'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current PIN'), findsOneWidget);
    await _type(tester, '1111');
    expect(find.text('That PIN is not right. Try again.'), findsOneWidget);
    expect(values.values, contains('akatabo.pin.hash'));

    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(await _stored(tester, db, PrivacyKeys.lockOn.name), '0');
    expect(values.values, isEmpty);
  });

  testWidgets('Change PIN checks the old one, then takes the new one', (tester) async {
    final values = await valuesWithPin('2580');
    final before = values.values['akatabo.pin.hash'];
    await _pump(tester, db, values, settings: {PrivacyKeys.lockOn.name: '1'});
    await _settle(tester);
    await tester.tap(find.text('Change PIN'));
    await tester.pumpAndSettle();
    await _type(tester, '2580');
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await _type(tester, '9753');
    await _type(tester, '9753');
    await tester.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(values.values['akatabo.pin.hash'], isNot(before));
  });

  testWidgets('Lock after is chosen from a sheet and saved', (tester) async {
    await _pump(tester, db, await valuesWithPin('2580'), settings: {PrivacyKeys.lockOn.name: '1'});
    await _settle(tester);
    expect(find.text('1 minute away'), findsOneWidget);
    await tester.tap(find.text('Lock after'));
    await tester.pumpAndSettle();
    for (final a in LockAfter.values) {
      expect(find.text(a.label), findsWidgets, reason: a.label);
    }
    await tester.tap(find.text('5 minutes away'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(await _stored(tester, db, PrivacyKeys.lockAfter.name), LockAfter.fiveMinutes.name);
  });

  testWidgets('fingerprint or face is saved only once the phone recognises the person', (
    tester,
  ) async {
    final bio = FakeBiometrics(result: BiometricResult.failed);
    await _pump(
      tester,
      db,
      await valuesWithPin('2580'),
      settings: {PrivacyKeys.lockOn.name: '1'},
      biometrics: bio,
    );
    await _settle(tester);
    await tester.tap(find.text('Fingerprint or face'));
    await _settle(tester);
    expect(bio.asked, 1);
    expect(find.text('Not recognised, so Akatabo still unlocks with your PIN.'), findsOneWidget);
    expect(await _stored(tester, db, PrivacyKeys.unlockWith.name), isNull);

    bio.result = BiometricResult.passed;
    await tester.tap(find.text('Fingerprint or face'));
    await _settle(tester);
    expect(await _stored(tester, db, PrivacyKeys.unlockWith.name), UnlockMethod.biometric.name);
  });

  testWidgets('no "Unlock with" on a phone without fingerprint or face', (tester) async {
    await _pump(
      tester,
      db,
      await valuesWithPin('2580'),
      settings: {PrivacyKeys.lockOn.name: '1'},
      biometrics: FakeBiometrics(available: false),
    );
    await _settle(tester);
    expect(find.text('Unlock with'), findsNothing);
  });

  testWidgets('Hide amounts and the app switcher switches save', (tester) async {
    await _pump(tester, db, MapSecureValues());
    await tester.tap(find.bySemanticsLabel('Hide amounts'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Blank the screen in the app switcher'));
    await _settle(tester);
    expect(await _stored(tester, db, PrivacyKeys.hideAmounts.name), '1');
    expect(await _stored(tester, db, PrivacyKeys.blankInSwitcher.name), '0');
  });

  for (final b in Brightness.values) {
    testWidgets('matches the drawn section, ${b.name}', (tester) async {
      await _pump(
        tester,
        db,
        await valuesWithPin('2580'),
        settings: _drawn,
        biometrics: FakeBiometrics(),
        brightness: b,
      );
      await _settle(tester);
      await expectLater(
        find.byType(SettingsPage),
        matchesGoldenFile('goldens/privacy_section_${b.name}.png'),
      );
    });
  }

  for (final b in Brightness.values) {
    testWidgets('PIN set screen (undrawn), ${b.name}', (tester) async {
      await _pump(tester, db, MapSecureValues(), brightness: b);
      await tester.tap(find.bySemanticsLabel('Lock the app'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PinFlowScreen),
        matchesGoldenFile('goldens/pin_set_${b.name}.png'),
      );
    });
  }
}
