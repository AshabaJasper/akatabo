import 'dart:isolate';
import 'dart:typed_data';

import 'csv_writer.dart';
import 'export_report.dart';
import 'pdf_report.dart';
import 'xlsx_writer.dart';

/// The bytes of [report] in [format]. Pure Dart, so it can run in a background isolate.
/// [fonts] are needed for the PDF report only.
Future<Uint8List> buildExportBytes(ExportReport report, ExportFormat format, PdfFonts? fonts) =>
    switch (format) {
      ExportFormat.csv => Future.value(buildCsv(report)),
      ExportFormat.excel => Future.value(buildExcel(report)),
      ExportFormat.pdf => buildPdfReport(
        report,
        fonts ?? (throw ArgumentError('The PDF report needs its fonts')),
      ),
    };

/// [buildExportBytes] on a background isolate, so a long history does not freeze the screen
/// while its file is made. Top level, so the closure carries only these three values.
Future<Uint8List> buildExportBytesInBackground(
  ExportReport report,
  ExportFormat format,
  PdfFonts? fonts,
) => Isolate.run(() => buildExportBytes(report, format, fonts));
