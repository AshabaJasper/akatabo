import 'package:akatabo/app/routes.dart';
import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/features/settings/settings_entries.dart';
import 'package:akatabo/features/settings/settings_screen.dart';
import 'package:akatabo/features/settings/settings_search.dart';
import 'package:akatabo/widgets/ak_empty_note.dart';
import 'package:akatabo/widgets/ak_surfaces.dart';
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _Item implements SearchableSetting {
  const _Item(this.label, this.description, [this.keywords = const []]);
  @override
  final String label;
  @override
  final String description;
  @override
  final List<String> keywords;
}

const _items = [
  _Item('Reminders', 'Daily nudge, budget warnings'),
  _Item('Appearance', 'Theme, colours, text size', ['dark']),
  _Item('Data and backup', 'Export, back up, restore'),
];

List<String> _labels(List<SearchableSetting> list) => [for (final e in list) e.label];

Future<void> _pump(
  WidgetTester tester, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Each page the hub opens is a stand-in that names itself, so a tap can go there and back.
  final pages = {for (final e in settingsEntries) Uri.parse(e.route).pathSegments.last};
  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: [
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          for (final page in pages)
            GoRoute(
              path: page,
              builder: (_, _) => Scaffold(body: Text('Page $page')),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(
        theme: buildAkTheme(Brightness.light, const AkAppearance()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  group('filterSettings', () {
    test('a term matches the label or the description, ignoring case', () {
      expect(_labels(filterSettings(_items, 'REMIND')), ['Reminders']);
      expect(_labels(filterSettings(_items, 'restore')), ['Data and backup']);
      expect(_labels(filterSettings(_items, 'dark')), ['Appearance'], reason: 'a keyword');
    });

    test('every word must match, in any order', () {
      expect(_labels(filterSettings(_items, '  backup   export ')), ['Data and backup']);
      expect(filterSettings(_items, 'backup dark'), isEmpty);
    });

    test('a term that matches nothing gives an empty list', () {
      expect(filterSettings(_items, 'loans'), isEmpty);
    });

    test('a cleared or blank term gives every entry, in order', () {
      expect(_labels(filterSettings(_items, '')), _labels(_items));
      expect(_labels(filterSettings(_items, '   ')), _labels(_items));
    });

    test('the real entries are each found by their own name', () {
      for (final entry in settingsEntries) {
        expect(filterSettings(settingsEntries, entry.label), contains(entry));
      }
    });

    test('each hidden keyword finds exactly the pages that have that thing', () {
      // A table, so a keyword on the wrong page fails here. "password" once pointed only at
      // App lock, though a backup also has one.
      const expected = <String, Set<String>>{
        'password': {'App lock', 'Data and backup'},
        'csv': {'Data and backup'},
        'notifications': {'Reminders', 'Phone permissions'},
        'font': {'Appearance'},
        'dark': {'Appearance'},
        'ugx': {'General'},
        'mobile money': {'Accounts'},
        'income': {'Categories'},
        'layout': {'Home screen'},
        'predictions': {'Smart help'},
        'biometric': {'App lock'},
        'hide amounts': {'Privacy and security'},
        'gpl': {'About Akatabo'},
        'github': {'About Akatabo'},
        'license': {'About Akatabo'},
      };
      expected.forEach((term, pages) {
        final found = filterSettings(settingsEntries, term).map((e) => e.label).toSet();
        expect(found, pages, reason: 'searching "$term"');
      });
    });
  });

  group('the Settings search field', () {
    testWidgets('typing shows only the matching rows, and clearing brings all back', (
      tester,
    ) async {
      // The hub is a lazy list: tall enough that every row is built and can be counted.
      await _pump(tester, size: const Size(390, 1600));
      expect(find.byType(AkIconTile), findsNWidgets(settingsEntries.length));

      await tester.enterText(find.byType(TextField), 'backup');
      await tester.pump();
      expect(find.text('Data and backup'), findsOneWidget);
      expect(find.text('Reminders'), findsNothing);
      expect(find.byType(AkIconTile), findsOneWidget);
      expect(find.byType(AkCard), findsOneWidget, reason: 'cards with no match are left out');

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byType(AkIconTile), findsNWidgets(settingsEntries.length));
      expect(
        find.byType(AkCard),
        findsNWidgets(settingsEntries.map((e) => e.group).toSet().length),
      );
      expect(find.byType(AkEmptyNote), findsNothing);
    });

    testWidgets('a term with no match shows the empty note', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'loans');
      await tester.pump();
      expect(find.byType(AkIconTile), findsNothing);
      expect(find.byType(AkEmptyNote), findsOneWidget);
      expect(find.text('No settings match. Try another word.'), findsOneWidget);
    });

    testWidgets('the field is named for screen readers', (tester) async {
      await _pump(tester);
      final handle = tester.ensureSemantics();
      // The name sits on the edit box TalkBack focuses, not on a node around it.
      final field = tester.getSemantics(find.byType(EditableText));
      expect(field.flagsCollection.isTextField, isTrue);
      expect(field.label, contains('Search settings'));
      handle.dispose();
    });

    testWidgets('at double text size the field and rows fit without overflow', (tester) async {
      await _pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'lock');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('App lock'), findsOneWidget);
    });

    testWidgets('the hint fits on one line at 1.3 times text size', (tester) async {
      await _pump(tester, textScale: 1.3);
      final hint = tester.renderObject<RenderParagraph>(find.text(settingsSearchHint));
      expect(hint.didExceedMaxLines, isFalse);
    });

    testWidgets('the field keeps its words when it scrolls away and back', (tester) async {
      await _pump(tester, textScale: 2);
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();
      final shown = find.byType(AkIconTile).evaluate().length;
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pump();
      expect(_fieldText(tester), 'e');
      expect(find.byType(AkIconTile).evaluate().length, lessThanOrEqualTo(shown));
    });

    testWidgets('opening a result closes the keyboard, and it stays shut on the way back', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'lock');
      await tester.pump();
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(find.text('Page lock'), findsOneWidget);

      GoRouter.of(tester.element(find.text('Page lock'))).pop();
      await tester.pumpAndSettle();
      expect(_fieldText(tester), 'lock', reason: 'the search is still there');
      final focus = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('the number of results is announced once typing pauses', (tester) async {
      await _pump(tester);
      tester.takeAnnouncements();
      await tester.enterText(find.byType(TextField), 'lock');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeAnnouncements().map((a) => a.message), ['1 setting']);

      await tester.enterText(find.byType(TextField), 'loans');
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeAnnouncements().map((a) => a.message), ['No settings match']);
    });

    test('"password" finds both App lock and the backup password', () {
      expect(
        _labels(filterSettings(settingsEntries, 'password')),
        containsAll(['App lock', 'Data and backup']),
      );
    });
  });
}
