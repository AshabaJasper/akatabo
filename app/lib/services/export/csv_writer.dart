/// The CSV export: UTF-8 with a byte order mark, comma separated, CRLF line ends (RFC 4180).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'export_report.dart';

/// The UTF-8 byte order mark. Excel on Windows reads a CSV without it in the local code page,
/// so a name such as "Kafeero's café" or the "UGX" note would come out garbled.
const csvBom = [0xEF, 0xBB, 0xBF];

final _csvDate = DateFormat('yyyy-MM-dd HH:mm');

/// Characters that make a spreadsheet treat a cell as a formula (and the tab and carriage
/// return that some spreadsheets strip before checking). A text cell starting with one is
/// written with a leading apostrophe, so `=HYPERLINK(...)` typed as a description stays text.
const _formulaStarts = {'=', '+', '-', '@', '\t', '\r'};

/// One field, made safe: formula starts are neutralised, then the field is quoted when it
/// holds a comma, a quote or a line break, with quotes doubled.
String csvField(String raw, {bool isText = true}) {
  var s = raw;
  if (isText && s.isNotEmpty && _formulaStarts.contains(s[0])) s = "'$s";
  final needsQuotes = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
  return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
}

String _cell(ExportCell c) => switch (c.value) {
  null => '',
  final int n => csvField('$n', isText: false),
  final DateTime d => csvField(_csvDate.format(d), isText: false),
  final String s => csvField(s),
  final Object other => csvField('$other'),
};

String _table(ExportTable t) => [
  t.headers.map(csvField).join(','),
  for (final row in t.rows) row.map(_cell).join(','),
].join('\r\n');

/// The CSV for [report]. One table: the transactions, or the category totals when only they
/// are chosen. With both chosen, the category table follows the transactions after one empty
/// line, with its own header row, so a spreadsheet opens both.
Uint8List buildCsv(ExportReport report) {
  final o = report.options;
  final parts = [
    if (o.transactions) _table(report.transactionTable()),
    if (o.categoryTotals) _table(report.categoryTable()),
  ];
  final text = '${parts.join('\r\n\r\n')}\r\n';
  return Uint8List.fromList([...csvBom, ...utf8.encode(text)]);
}
