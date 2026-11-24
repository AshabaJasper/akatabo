import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../services/export/export_file.dart';
import '../../services/export/export_report.dart';
import '../../services/export/pdf_report.dart';

// Written by hand: these name drift's generated row classes (see add_providers.dart).

/// Every stored entry, for the counts on Export and back up and for the export itself. An
/// export reads all of them because a month's carry-over needs the month before it.
final exportAllRowsProvider = StreamProvider.autoDispose<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);

/// The size of the database in bytes, from SQLite's own page count, so it works the same for
/// the file on the phone and the in-memory database in tests. Worked out again when the
/// entries change.
final exportDatabaseSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(exportAllRowsProvider);
  final db = ref.watch(appDatabaseProvider);
  final row = await db
      .customSelect(
        'SELECT page_count * page_size AS size FROM pragma_page_count(), pragma_page_size()',
      )
      .getSingle();
  return row.read<int>('size');
});

/// Makes an export's bytes: on a background isolate in the app. Widget tests replace it with
/// [buildExportBytes] on the test's own isolate, which the test clock can wait for.
final exportBytesBuilderProvider =
    Provider<Future<Uint8List> Function(ExportReport, ExportFormat, PdfFonts?)>(
      (ref) => buildExportBytesInBackground,
    );

/// The static Geist faces the PDF report is set in.
final pdfFontsProvider = FutureProvider<PdfFonts>((ref) async {
  final regular = await rootBundle.load(pdfRegularAsset);
  final semiBold = await rootBundle.load(pdfSemiBoldAsset);
  // The logo is a nicety: if it cannot be read, the header falls back to the word and the
  // export still works.
  Uint8List? logo;
  try {
    final bytes = await rootBundle.load(pdfLogoAsset);
    logo = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } on Object catch (e) {
    debugPrint('PDF logo could not be read: $e');
  }
  return PdfFonts(regular: regular, semiBold: semiBold, logo: logo);
});
