/// A small .xlsx writer: SpreadsheetML parts in a zip. Written in-house because the `excel`
/// package needs `xml <7` while `pdf` needs `xml >=7.0.1` (PLAN.md, Packages).
///
/// It writes only what an export needs: text as inline strings, whole shillings as number
/// cells shown as `#,##0`, moments as real date cells shown as `yyyy-mm-dd hh:mm`, a bold
/// header row that stays in view, and one sheet per table.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'export_report.dart';

// Style indexes in styles.xml: 0 plain, 1 header, 2 amount, 3 date and time.
const _styleHeader = 1;
const _styleAmount = 2;
const _styleDate = 3;

/// Characters XML 1.0 cannot hold at all (control characters other than tab and line ends).
final _invalidXml = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]');

String _xml(String s) => s
    .replaceAll(_invalidXml, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// The column letters for a zero-based index: 0 is A, 25 is Z, 26 is AA.
String columnName(int index) {
  var n = index + 1;
  var name = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    name = String.fromCharCode(65 + r) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

/// A moment as a spreadsheet serial: days since 30 December 1899, the fraction being the time
/// of day. The phone's local date and time are kept as written, with no time zone shift.
double excelSerial(DateTime d) {
  final asWritten = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  return asWritten.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
}

String _cellXml(ExportCell c, String ref) => switch (c.value) {
  null => '',
  final int n => '<c r="$ref" s="$_styleAmount"><v>$n</v></c>',
  final DateTime d => '<c r="$ref" s="$_styleDate"><v>${excelSerial(d)}</v></c>',
  final Object s =>
    s.toString().isEmpty
        ? ''
        : '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_xml('$s')}</t></is></c>',
};

String _sheetXml(ExportTable t) {
  final b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetViews><sheetView workbookViewId="0">'
    '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
    '</sheetView></sheetViews>'
    '<cols>',
  );
  for (var i = 0; i < t.headers.length; i++) {
    // Wide enough for the header and for a figure such as 1,284,000 or a date and time.
    final width = (t.headers[i].length + 4).clamp(14, 40);
    b.write('<col min="${i + 1}" max="${i + 1}" width="$width" customWidth="1"/>');
  }
  b.write('</cols><sheetData><row r="1">');
  for (var i = 0; i < t.headers.length; i++) {
    b.write(
      '<c r="${columnName(i)}1" t="inlineStr" s="$_styleHeader">'
      '<is><t>${_xml(t.headers[i])}</t></is></c>',
    );
  }
  b.write('</row>');
  for (var r = 0; r < t.rows.length; r++) {
    final rowNumber = r + 2;
    b.write('<row r="$rowNumber">');
    final row = t.rows[r];
    for (var i = 0; i < row.length; i++) {
      b.write(_cellXml(row[i], '${columnName(i)}$rowNumber'));
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

const _contentTypesHead =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/></numFmts>'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="4">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    // 3 is the built-in "#,##0".
    '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

/// A workbook with one sheet per table, in order. Sheet names must be unique and at most 31
/// characters; the export's names ("Transactions", "Categories") are.
Uint8List buildXlsx(List<ExportTable> tables) {
  if (tables.isEmpty) {
    throw ArgumentError('A workbook needs at least one sheet');
  }
  final contentTypes = StringBuffer(_contentTypesHead);
  final sheets = StringBuffer();
  final rels = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
  );
  final sheetFiles = <ArchiveFile>[];
  for (var i = 0; i < tables.length; i++) {
    final n = i + 1;
    contentTypes.write(
      '<Override PartName="/xl/worksheets/sheet$n.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
    sheets.write('<sheet name="${_xml(tables[i].name)}" sheetId="$n" r:id="rId$n"/>');
    rels.write(
      '<Relationship Id="rId$n" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$n.xml"/>',
    );
    sheetFiles.add(_file('xl/worksheets/sheet$n.xml', _sheetXml(tables[i])));
  }
  final stylesId = tables.length + 1;
  rels.write(
    '<Relationship Id="rId$stylesId" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/></Relationships>',
  );
  contentTypes.write('</Types>');
  final workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>$sheets</sheets></workbook>';

  // [Content_Types].xml first, as Office writes it; some readers expect it there.
  final archive = Archive()
    ..addFile(_file('[Content_Types].xml', contentTypes.toString()))
    ..addFile(_file('_rels/.rels', _rootRels))
    ..addFile(_file('xl/workbook.xml', workbook))
    ..addFile(_file('xl/_rels/workbook.xml.rels', rels.toString()))
    ..addFile(_file('xl/styles.xml', _styles));
  sheetFiles.forEach(archive.addFile);
  return ZipEncoder().encodeBytes(archive);
}

ArchiveFile _file(String name, String xml) => ArchiveFile.bytes(name, utf8.encode(xml));

/// The Excel file for [report]: the transactions sheet and, when chosen, the categories sheet.
Uint8List buildExcel(ExportReport report) => buildXlsx([
  if (report.options.transactions) report.transactionTable(),
  if (report.options.categoryTotals) report.categoryTable(),
]);
