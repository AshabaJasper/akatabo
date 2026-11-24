import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/features/settings/permissions_screen.dart';
import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/permissions/phone_permissions.dart';
import 'package:akatabo/services/security/biometrics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_notifications.dart';

/// A phone that reports [granted] and records each settings page opened.
class _FakePermissions implements PhonePermissions {
  _FakePermissions({this.granted, this.opens = true});
  Map<String, bool>? granted;
  bool opens;
  final opened = <PhoneSettingsPage>[];

  @override
  Future<Map<String, bool>?> requested() async => granted;

  @override
  Future<bool> open(PhoneSettingsPage page) async {
    opened.add(page);
    return opens;
  }
}

/// What a release build asks for on Android 13 and later.
const _release = {
  'android.permission.POST_NOTIFICATIONS': false,
  'android.permission.USE_BIOMETRIC': true,
};

Future<void> _pump(
  WidgetTester tester,
  _FakePermissions phone, {
  bool notificationsAllowed = true,
  bool biometrics = true,
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        phonePermissionsProvider.overrideWithValue(phone),
        notificationsServiceProvider.overrideWithValue(
          FakeNotifications(allowedNow: notificationsAllowed) as NotificationsService,
        ),
        biometricsAvailableProvider.overrideWith((ref) async => biometrics),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: const PermissionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('permission words', () {
    test('a release build never asks for internet, location, contacts and the rest', () {
      expect(neverAskedFor(_release.keys), [
        'internet',
        'location',
        'contacts',
        'camera',
        'microphone',
        'text messages',
        'your files and photos',
      ]);
    });

    test('a permission that is asked for drops out of the never-asked list', () {
      final never = neverAskedFor(['android.permission.INTERNET', 'android.permission.CAMERA']);
      expect(never, isNot(contains('internet')));
      expect(never, isNot(contains('camera')));
      expect(never, contains('location'));
    });

    test('words are joined with commas and a final "and"', () {
      expect(joinWords([]), '');
      expect(joinWords(['a']), 'a');
      expect(joinWords(['a', 'b']), 'a and b');
      expect(joinWords(['a', 'b', 'c']), 'a, b and c');
    });

    test('an unknown permission keeps its system name without the prefix', () {
      expect(permissionWords('android.permission.CAMERA').name, 'CAMERA');
      expect(permissionWords('android.permission.INTERNET').testBuildOnly, isTrue);
    });
  });

  group('Phone permissions', () {
    testWidgets('blocked notifications and a ready fingerprint read as the phone says', (
      tester,
    ) async {
      await _pump(tester, _FakePermissions(granted: _release), notificationsAllowed: false);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.textContaining('Akatabo never asks for internet, location'), findsOneWidget);
    });

    testWidgets('a phone with no fingerprint or face added says so', (tester) async {
      await _pump(tester, _FakePermissions(granted: _release), biometrics: false);
      expect(find.text('None added'), findsOneWidget);
      expect(find.text('Allowed'), findsOneWidget);
    });

    testWidgets('a test build lists internet as development only, and drops it from never', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakePermissions(granted: {..._release, 'android.permission.INTERNET': true}),
      );
      expect(find.text('Internet'), findsOneWidget);
      expect(find.textContaining('For development only'), findsOneWidget);
      expect(find.textContaining('never asks for location'), findsOneWidget);
    });

    testWidgets('where the phone cannot list permissions, no promise is made', (tester) async {
      await _pump(tester, _FakePermissions());
      expect(find.textContaining('never asks for'), findsNothing);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('each row opens its own page in the phone settings', (tester) async {
      final phone = _FakePermissions(granted: _release);
      await _pump(tester, phone);
      await tester.tap(find.text('Notifications'));
      await tester.tap(find.text('Fingerprint or face'));
      await tester.tap(find.text('Open Akatabo in phone settings'));
      await tester.pump();
      expect(phone.opened, [
        PhoneSettingsPage.notifications,
        PhoneSettingsPage.biometrics,
        PhoneSettingsPage.app,
      ]);
    });

    testWidgets('a screen reader can open a row as a button', (tester) async {
      final handle = tester.ensureSemantics();
      final phone = _FakePermissions(granted: _release);
      await _pump(tester, phone);
      final row = find.bySemanticsLabel(RegExp(r'^Notifications, Allowed'));
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Notifications, Allowed. Only for reminders you switch on',
          hint: "Opens the phone's settings",
        ),
      );
      tester.semantics.tap(find.semantics.byLabel(RegExp(r'^Notifications, Allowed')));
      await tester.pump();
      expect(phone.opened, [PhoneSettingsPage.notifications]);
      handle.dispose();
    });

    testWidgets('a settings page that cannot open says what to do instead', (tester) async {
      await _pump(tester, _FakePermissions(granted: _release, opens: false));
      await tester.tap(find.text('Notifications'));
      await tester.pump();
      expect(find.text(settingsNotOpenedMessage), findsOneWidget);
    });

    testWidgets('coming back to the app reads the permissions again', (tester) async {
      final phone = _FakePermissions(granted: _release);
      await _pump(tester, phone);
      expect(find.text('CAMERA'), findsNothing);
      phone.granted = {..._release, 'android.permission.CAMERA': true};
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.text('CAMERA'), findsOneWidget);
    });

    for (final b in Brightness.values) {
      testWidgets('phone permissions golden, ${b.name}', (tester) async {
        await _pump(
          tester,
          _FakePermissions(granted: _release),
          notificationsAllowed: false,
          brightness: b,
        );
        await expectLater(
          find.byType(PermissionsScreen),
          matchesGoldenFile('goldens/permissions_${b.name}.png'),
        );
      });
    }
  });
}
