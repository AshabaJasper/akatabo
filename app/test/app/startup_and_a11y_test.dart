import 'package:akatabo/app/appearance.dart';
import 'package:akatabo/app/bootstrap.dart';
import 'package:akatabo/app/shell_scaffold.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/widgets/ak_surfaces.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // A plain test, not a widget test: a real drift database inside the widget test's fake
  // clock never finishes its stream work and wedges the binding. The app's first build
  // reads appearanceProvider synchronously, so if the value is already there when the
  // container is returned, the first frame uses it.
  test('stored appearance is ready before the first frame', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(db).write(SettingKeys.theme, ThemeMode.dark);
    await SettingsRepository(db).write(SettingKeys.corners, AkCorners.square);

    final container = await createAppContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final appearance = container.read(appearanceProvider);
    expect(appearance.themeMode, ThemeMode.dark);
    expect(appearance.corners, AkCorners.square);
  });

  group('screen readers can activate every navigation control', () {
    Future<void> pumpNav(WidgetTester tester, {double textScale = 1}) async {
      tester.view
        ..physicalSize = const Size(360, 120)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAkTheme(Brightness.light, const AkAppearance()),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 120),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              bottomNavigationBar: AkBottomNav(currentIndex: 0, onSelect: (_) {}, onAdd: () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('tabs and the Add disc have a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpNav(tester);
      for (final label in ['Home', 'Insights', 'Add a transaction', 'Goals', 'Settings']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label).last),
          isSemantics(isButton: true, hasTapAction: true),
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('labels stay inside their slot at twice the text size on a 360dp phone', (
      tester,
    ) async {
      await pumpNav(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      const slot = 360 / 5;
      for (final (i, label) in ['Home', 'Insights', '', 'Goals', 'Settings'].indexed) {
        if (label.isEmpty) continue;
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(slot * i - 0.5), reason: label);
        expect(rect.right, lessThanOrEqualTo(slot * (i + 1) + 0.5), reason: label);
      }
    });

    testWidgets('the back link has a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAkTheme(Brightness.light, const AkAppearance()),
          home: Scaffold(body: AkBackLink('Settings', onTap: () {})),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Back to Settings')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });
}
