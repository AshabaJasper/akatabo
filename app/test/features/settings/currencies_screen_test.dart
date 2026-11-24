import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/repositories/repositories.dart';
import 'package:akatabo/data/settings/setting_keys.dart';
import 'package:akatabo/features/settings/currencies_screen.dart';
import 'package:akatabo/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the settings the page writes instead of writing to a database.
class _RecordingSettings extends SettingsRepository {
  _RecordingSettings() : super(AppDatabase(NativeDatabase.memory()));

  final written = <String, String>{};

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async => written[key.name] = '$value';
}

Future<_RecordingSettings> _pump(
  WidgetTester tester, {
  Map<String, String> stored = const {'rate.USD': '3720000000'},
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _RecordingSettings();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storedSettingsProvider.overrideWith((ref) => Stream.value(stored)),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        home: const CurrenciesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Finder _dialogField() =>
    find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

void main() {
  testWidgets('a rate that is not one keeps the box open with the reason', (tester) async {
    final settings = await _pump(tester);
    await tester.tap(find.text('3,720 UGX'));
    await tester.pumpAndSettle();
    expect(find.text('Rate for USD'), findsOneWidget);

    await tester.enterText(_dialogField(), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Rate for USD'), findsOneWidget, reason: 'the box stays open');
    expect(find.text('Type a rate above zero, such as 3,720.'), findsOneWidget);
    expect(settings.written, isEmpty);

    await tester.enterText(_dialogField(), '3800');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Rate for USD'), findsNothing);
    expect(settings.written['rate.USD'], '3800000000');
  });

  testWidgets('the empty note is inset like the rows, not flush with the card edge', (
    tester,
  ) async {
    await _pump(tester, stored: const {});
    final label = tester.getTopLeft(find.text('REMEMBERED RATES'));
    final note = tester.getTopLeft(find.textContaining('No rates yet'));
    expect(note.dx - label.dx, closeTo(settingsRowSide, 0.5), reason: 'inset and left-aligned');
  });

  testWidgets('Remove clears the remembered rate', (tester) async {
    final settings = await _pump(tester);
    await tester.tap(find.text('3,720 UGX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(settings.written['rate.USD'], '');
  });
}
