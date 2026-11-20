import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:akatabo/core/theme/ak_theme.dart';
import 'package:akatabo/core/theme/contrast.dart';
import 'package:akatabo/core/theme/tokens.g.dart' show akPalettes;
import 'package:akatabo/core/time/clock_provider.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/providers.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/features/add/add_providers.dart';
import 'package:akatabo/features/data/export_backup_screen.dart';
import 'package:akatabo/features/data/export_providers.dart';
import 'package:akatabo/features/data/export_section.dart';
import 'package:akatabo/features/home/home_providers.dart';
import 'package:akatabo/services/export/csv_writer.dart';
import 'package:akatabo/services/export/export_destination.dart';
import 'package:akatabo/services/export/export_file.dart';
import 'package:akatabo/services/export/pdf_report.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../flutter_test_config.dart';
import '../../support/fixtures.dart';

/// Records each file it is handed instead of opening the phone's dialogs.
class _FakeDestination implements ExportDestination {
  final calls = <({String how, String fileName, String mimeType, Uint8List bytes})>[];
  Rect? lastOrigin;

  @override
  Future<bool> save({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    calls.add((how: 'save', fileName: fileName, mimeType: mimeType, bytes: bytes));
    return true;
  }

  @override
  Future<bool> share({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) async {
    lastOrigin = origin;
    calls.add((how: 'share', fileName: fileName, mimeType: mimeType, bytes: bytes));
    return true;
  }
}

final _rows = [
  txRow(id: 'a', amount: 45000, fee: 1000, description: 'Market', at: DateTime(2026, 11, 3)),
  txRow(id: 'b', amount: 2000, description: 'Boda', at: DateTime(2026, 11, 12)),
  txRow(id: 'c', amount: 8000, description: 'Lunch', at: DateTime(2026, 11, 18)),
  txRow(id: 'd', amount: 5000, description: 'Airtime', at: DateTime(2026, 10, 20)),
];

final _cats = [
  categoryRow(id: DefaultIds.food, name: 'Food', monthlyBudget: 300000),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
];

final _accounts = [accountRow(id: DefaultIds.mtn, name: 'MTN MoMo')];

Future<_FakeDestination> _pump(
  WidgetTester tester, {
  List<Transaction>? rows,
  bool startOnPdf = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 1400),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final destination = _FakeDestination();
  final fonts = PdfFonts(
    regular: ByteData.sublistView(File(pdfRegularAsset).readAsBytesSync()),
    semiBold: ByteData.sublistView(File(pdfSemiBoldAsset).readAsBytesSync()),
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storedSettingsProvider.overrideWith((ref) => Stream.value(const {})),
        appNowProvider.overrideWithValue(testNow),
        exportAllRowsProvider.overrideWith((ref) => Stream.value(rows ?? _rows)),
        exportDatabaseSizeProvider.overrideWith((ref) async => 420000),
        allCategoriesProvider.overrideWith((ref) => Stream.value(_cats)),
        allAccountsProvider.overrideWith((ref) => Stream.value(_accounts)),
        exportDestinationProvider.overrideWithValue(destination),
        exportBytesBuilderProvider.overrideWithValue(buildExportBytes),
        pdfFontsProvider.overrideWith((ref) async => fonts),
      ],
      child: MaterialApp(
        theme: buildAkTheme(brightness, const AkAppearance()),
        home: ExportBackupScreen(startOnPdf: startOnPdf),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return destination;
}

bool _enabled(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).flagsCollection.isEnabled == Tristate.isTrue;

Finder _exportButton() => find.ancestor(
  of: find.textContaining(RegExp(r'^(Export|Making)')),
  matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true),
);

bool _selected(WidgetTester tester, String segment) =>
    tester.getSemantics(find.text(segment)).flagsCollection.isSelected == Tristate.isTrue;

Future<void> _exportVia(WidgetTester tester, String choice) async {
  await tester.ensureVisible(_exportButton().first);
  await tester.tap(_exportButton().first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice));
  // The file is made between frames; give each await a frame and a moment of real time.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the note and the button count real entries', (tester) async {
    await _pump(tester);
    expect(find.text('Your data lives on this phone only'), findsOneWidget);
    expect(
      find.text('4 transactions, 0.4 MB. If you lose the phone without a backup, it is gone.'),
      findsOneWidget,
    );
    // Three of the four fall in November.
    expect(find.text('Export 3 transactions'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'the count beside Transactions');
    expect(find.text('November 2026'), findsOneWidget);
    expect(_enabled(tester, _exportButton().first), isTrue);
    expect(find.text('You choose where the file is saved or who to send it to.'), findsOneWidget);
  });

  testWidgets('the count follows the period', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('Export 4 transactions'), findsOneWidget);
    expect(find.text('Every entry, whatever its date.'), findsOneWidget);
  });

  testWidgets('with no entries at all, the button is off and says why', (tester) async {
    await _pump(tester, rows: const []);
    expect(find.text('Export 0 transactions'), findsOneWidget);
    expect(_enabled(tester, _exportButton().first), isFalse);
    expect(find.text('There are no transactions yet.'), findsOneWidget);
  });

  testWidgets('with none in the period, the button is off and says why', (tester) async {
    await _pump(tester, rows: [_rows.last]);
    expect(_enabled(tester, _exportButton().first), isFalse);
    expect(find.text('There are no transactions in this period.'), findsOneWidget);
  });

  testWidgets('the fee and note columns need Transactions; nothing chosen turns it off', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Transactions'));
    await tester.pump();
    expect(find.text('Export category totals'), findsOneWidget);
    expect(tester.getSemantics(find.text('Notes')).flagsCollection.isEnabled, Tristate.isFalse);
    expect(_enabled(tester, find.text('Category totals and budgets')), isTrue);
    await tester.tap(find.text('Category totals and budgets'));
    await tester.pump();
    expect(_enabled(tester, _exportButton().first), isFalse);
    expect(find.text('Choose what to include.'), findsOneWidget);
  });

  testWidgets('Custom shows the first and last day, starting on this month', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Custom'));
    await tester.pump();
    expect(find.text('From'), findsOneWidget);
    expect(find.text('1 Nov 2026'), findsOneWidget);
    expect(find.text('19 Nov 2026'), findsOneWidget);
    expect(find.text('Export 3 transactions'), findsOneWidget);
  });

  testWidgets('it opens on CSV for This month', (tester) async {
    await _pump(tester);
    expect(_selected(tester, 'CSV'), isTrue);
    expect(_selected(tester, 'PDF report'), isFalse);
    expect(_selected(tester, 'This month'), isTrue);
  });

  testWidgets('"Export a monthly report" opens on the PDF report for This month', (tester) async {
    await _pump(tester, startOnPdf: true);
    expect(_selected(tester, 'PDF report'), isTrue);
    expect(_selected(tester, 'CSV'), isFalse);
    expect(_selected(tester, 'This month'), isTrue);
  });

  testWidgets('saving hands the CSV to the save dialog under its file name', (tester) async {
    final destination = await _pump(tester);
    await _exportVia(tester, 'Save it to a folder');
    expect(destination.calls, hasLength(1));
    final call = destination.calls.single;
    expect(call.how, 'save');
    expect(call.fileName, 'akatabo-2026-11.csv');
    expect(call.mimeType, 'text/csv');
    expect(call.bytes.sublist(0, 3), csvBom);
    expect(find.text('Saved akatabo-2026-11.csv.'), findsOneWidget);
  });

  testWidgets('the monthly report is shared as a PDF', (tester) async {
    final destination = await _pump(tester, startOnPdf: true);
    await _exportVia(tester, 'Send or share it');
    final call = destination.calls.single;
    expect(call.how, 'share');
    expect(call.fileName, 'akatabo-2026-11.pdf');
    expect(call.mimeType, 'application/pdf');
    expect(String.fromCharCodes(call.bytes.sublist(0, 5)), '%PDF-');
    expect(destination.lastOrigin, isNotNull, reason: 'a tablet needs a point to open from');
  });

  testWidgets('a PDF without the list of entries is still a report', (tester) async {
    await _pump(tester, startOnPdf: true);
    await tester.tap(find.text('Transactions'));
    await tester.pump();
    expect(find.text('Export the report'), findsOneWidget);
    await tester.tap(find.text('Category totals and budgets'));
    await tester.pump();
    expect(find.text('Export the report'), findsOneWidget);
    expect(find.text('Choose what to include.'), findsNothing);
  });

  testWidgets('closing the choice sends nothing', (tester) async {
    final destination = await _pump(tester);
    await tester.ensureVisible(_exportButton().first);
    await tester.tap(_exportButton().first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(destination.calls, isEmpty);
  });

  for (final b in Brightness.values) {
    testWidgets('golden: Export and back up, ${b.name}', (tester) async {
      await _pump(tester, brightness: b, size: const Size(390, 844));
      await expectLater(
        find.byType(ExportBackupScreen),
        matchesGoldenFile('goldens/export_${b.name}.png'),
      );
    });
  }

  // The app's target is 44px (DESIGN_SYSTEM.md), so Android's 48px guideline is not used.
  testWidgets('every target is labelled and at least 44 pixels tall', (tester) async {
    await _pump(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    for (final label in [
      'Transactions',
      'Fees and tax as their own column',
      'Category totals and budgets',
      'Notes',
      'CSV',
      'Custom',
    ]) {
      final row = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44), reason: label);
    }
    expect(tester.getSize(_exportButton().first).height, greaterThanOrEqualTo(44));
  });

  test('sizes are written as drawn', () {
    expect(databaseSize(420000), '0.4 MB');
    expect(databaseSize(20000), 'under 0.1 MB');
    expect(databaseSize(15 * 1024 * 1024), '15 MB');
    expect(transactionCount(1), '1 transaction');
    expect(transactionCount(1284), '1,284 transactions');
  });

  test('the note card reads in both themes and every main colour', () {
    for (final b in Brightness.values) {
      for (final p in akPalettes) {
        final c = buildAkTheme(b, AkAppearance(paletteId: p.id)).extension<AkColors>()!.tokens;
        final where = '${b.name} ${p.id}';
        expect(contrastRatio(c.onBrand, c.brandDeep), greaterThanOrEqualTo(4.5), reason: where);
        expect(
          contrastRatio(c.onBrandMuted, c.brandDeep),
          greaterThanOrEqualTo(4.5),
          reason: where,
        );
        // The export button: on-brand on brand.
        expect(contrastRatio(c.onBrand, c.brand), greaterThanOrEqualTo(4.5), reason: where);
        expect(contrastRatio(c.accent, c.brandRaised), greaterThanOrEqualTo(3), reason: where);
      }
      final c = buildAkTheme(b, const AkAppearance()).extension<AkColors>()!.tokens;
      expect(contrastRatio(c.inkMuted, c.surface), greaterThanOrEqualTo(4.5), reason: b.name);
      expect(contrastRatio(c.inkMuted, c.surface), greaterThanOrEqualTo(4.5));
      // The empty tick box edge against the card: 3:1 for a control's boundary.
      expect(contrastRatio(c.inkMuted, c.surface), greaterThanOrEqualTo(3));
    }
  });

  test('the section keeps its startOnPdf flag', () {
    expect(const ExportSection(startOnPdf: true).startOnPdf, isTrue);
  });
}
