import 'dart:async';

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/lock/lock_gate.dart';
import 'package:akatabo/features/lock/lock_screen.dart';
import 'package:akatabo/services/security/biometrics.dart';
import 'package:akatabo/services/security/lock_controller.dart';
import 'package:akatabo/services/security/privacy_settings.dart';
import 'package:akatabo/widgets/ak_hidden_amount.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_security.dart';

const _secret = 'UGX 1,284,000';
final _lockOn = {PrivacyKeys.lockOn.name: '1'};

class _Harness {
  _Harness(this.values, {FakeBiometrics? biometrics})
    : biometrics = biometrics ?? FakeBiometrics(available: false);
  final MapSecureValues values;
  final FakeBiometrics biometrics;
  final window = FakePrivacyWindow();
  int wiped = 0;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, String>? settings,
  MapSecureValues? values,
  FakeBiometrics? biometrics,
  AppDatabase? db,
  Brightness brightness = Brightness.light,
  Widget? home,
  Size size = const Size(390, 844),
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  tester.view
    ..physicalSize = size
    ..padding = padding
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = _Harness(values ?? await valuesWithPin('2580'), biometrics: biometrics);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        if (db != null) appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(settings ?? _lockOn)),
        ...securityOverrides(values: h.values, biometrics: h.biometrics, window: h.window),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        builder: (context, child) => LockGate(onWiped: () => h.wiped++, child: child!),
        home:
            home ??
            Scaffold(
              body: Center(
                child: AkHiddenAmount(
                  _secret,
                  style: buildAkTheme(
                    brightness,
                    const AkAppearance(),
                  ).extension<AkType>()!.figureXl,
                ),
              ),
            ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

Future<void> _type(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    // On a short screen the keypad scrolls; bring the key up before tapping it.
    final key = find.bySemanticsLabel(d).last;
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('locks on start: the app behind is not shown or read out', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    expect(find.bySemanticsLabel(_secret), findsNothing);
    semantics.dispose();
  });

  testWidgets('the right PIN opens the app; a wrong one says so', (tester) async {
    await _pump(tester);
    await _type(tester, '1111');
    expect(find.text('That PIN is not right. Try again.'), findsOneWidget);
    expect(find.byType(LockScreen), findsOneWidget);

    await _type(tester, '2580');
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('the fifth wrong PIN starts a wait and the keys stop working', (tester) async {
    await _pump(tester);
    for (var i = 0; i < 5; i++) {
      await _type(tester, '1111');
    }
    expect(find.textContaining('Too many wrong tries. Try again in 0:30.'), findsOneWidget);
    // Even the right PIN does nothing while the wait lasts.
    await _type(tester, '2580');
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('fingerprint is asked for as it opens, and the PIN is the fallback', (tester) async {
    final bio = FakeBiometrics(result: BiometricResult.failed);
    await _pump(
      tester,
      settings: {..._lockOn, PrivacyKeys.unlockWith.name: UnlockMethod.biometric.name},
      biometrics: bio,
    );
    await tester.pump();
    expect(bio.asked, 1);
    expect(find.text(lockHelp), findsOneWidget);
    expect(find.bySemanticsLabel('Unlock with fingerprint or face'), findsOneWidget);

    await _type(tester, '2580');
    expect(find.byType(LockScreen), findsNothing);
  });

  testWidgets('a recognised fingerprint opens the app', (tester) async {
    await _pump(
      tester,
      settings: {..._lockOn, PrivacyKeys.unlockWith.name: UnlockMethod.biometric.name},
      biometrics: FakeBiometrics(),
    );
    await tester.pump();
    expect(find.byType(LockScreen), findsNothing);
  });

  testWidgets('no fingerprint key unless it is chosen and the phone has one', (tester) async {
    await _pump(tester, biometrics: FakeBiometrics());
    expect(find.bySemanticsLabel('Unlock with fingerprint or face'), findsNothing);
  });

  testWidgets('with the lock off the app opens straight away', (tester) async {
    await _pump(tester, settings: const {});
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text(_secret), findsOneWidget);
  });

  testWidgets('"Forgot your PIN?" deletes everything and the PIN after a warning', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    await tester.runAsync(
      () => TransactionRepository(db).add(
        TransactionDraft(
          direction: Direction.moneyOut,
          amount: 45000,
          accountId: DefaultIds.mtn,
          categoryId: DefaultIds.food,
          occurredAt: DateTime(2026, 11, 19, 9),
        ),
      ),
    );
    final h = await _pump(tester, db: db);

    await tester.tap(find.text('Forgot your PIN?'));
    await tester.pumpAndSettle();
    expect(find.text('Delete everything to get back in?'), findsOneWidget);
    expect(find.textContaining('every entry, account, category, budget'), findsOneWidget);

    // Cancel changes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(h.values.values, isNotEmpty);

    await tester.tap(find.text('Forgot your PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(h.values.values, isEmpty, reason: 'PIN and wrong tries are gone');
    expect(h.wiped, 1);
    expect(find.byType(LockScreen), findsNothing);
    final left = await tester.runAsync(() => db.select(db.transactions).get());
    expect(left, isEmpty);
  });

  testWidgets('back while locked leaves the pages behind as they were', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('First page')),
        GoRoute(path: '/two', builder: (_, _) => const Text('Second page')),
      ],
    );
    addTearDown(router.dispose);
    final values = await valuesWithPin('2580');
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          storedSettingsProvider.overrideWith((ref) => Stream.value(_lockOn)),
          ...securityOverrides(values: values),
        ],
        child: MaterialApp.router(
          theme: buildAkTheme(Brightness.light, const AkAppearance()),
          routerConfig: router,
          builder: (context, child) => LockGate(onWiped: () {}, child: child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    unawaited(router.push('/two'));
    await tester.pump();
    expect(find.byType(LockScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(router.state.matchedLocation, '/two');

    await _type(tester, '2580');
    await tester.pumpAndSettle();
    expect(find.text('Second page'), findsOneWidget);
  });

  for (final (name, padding) in [
    ('without', FakeViewPadding.zero),
    ('with', const FakeViewPadding(top: 24, bottom: 48)),
  ]) {
    testWidgets('a 360 x 640 phone, $name system bars, shows the whole keypad', (tester) async {
      await _pump(tester, size: const Size(360, 640), padding: padding);
      await tester.pump();
      final key0 = tester.getRect(find.bySemanticsLabel('0').last);
      expect(key0.bottom, lessThanOrEqualTo(640 - padding.bottom));
      expect(key0.height, greaterThanOrEqualTo(AkSize.target));
    });
  }

  testWidgets('a tall phone keeps full-size keys', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(tester.getSize(find.bySemanticsLabel('0').last).height, AkSize.pinKey);
  });

  testWidgets('locking takes focus away from a field behind it', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      settings: {..._lockOn, PrivacyKeys.lockAfter.name: LockAfter.rightAway.name},
      home: Scaffold(body: TextField(focusNode: focus)),
    );
    await _type(tester, '2580');
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    final container = ProviderScope.containerOf(tester.element(find.byType(TextField)));
    container.read(lockControllerProvider.notifier).wentAway();
    await tester.pump();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(focus.hasFocus, isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse, reason: 'nothing behind the lock can take focus');
  });

  testWidgets('"Blank the screen in the app switcher" is applied at start-up', (tester) async {
    final h = await _pump(tester, settings: const {});
    expect(h.window.calls, [true]);
  });

  testWidgets('switched off, the app switcher shows the app', (tester) async {
    final h = await _pump(tester, settings: {PrivacyKeys.blankInSwitcher.name: '0'});
    expect(h.window.calls, [false]);
  });

  testWidgets('hidden amounts show dots until a figure is tapped', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, settings: {PrivacyKeys.hideAmounts.name: '1'});
    expect(find.text(_secret), findsNothing);
    expect(find.text(hiddenFigure), findsOneWidget);
    expect(find.bySemanticsLabel(hiddenFigureLabel), findsOneWidget);

    await tester.tap(find.text(hiddenFigure));
    await tester.pump();
    expect(find.text(_secret), findsOneWidget);
    semantics.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('lock screen matches the drawn screen, ${b.name}', (tester) async {
      await _pump(
        tester,
        brightness: b,
        settings: {..._lockOn, PrivacyKeys.unlockWith.name: UnlockMethod.biometric.name},
        biometrics: FakeBiometrics(result: BiometricResult.failed),
      );
      // Two digits typed, as drawn, after the fingerprint prompt was closed.
      await tester.tap(find.bySemanticsLabel('2').last);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('5').last);
      await tester.pump();
      await expectLater(find.byType(LockScreen), matchesGoldenFile('goldens/lock_${b.name}.png'));
    });
  }
}
