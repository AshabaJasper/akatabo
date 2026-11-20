import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:akatabo/core/time/period.dart';
import 'package:akatabo/data/db/app_database.dart';
import 'package:akatabo/data/seed/default_data.dart';
import 'package:akatabo/domain/fees.dart';
import 'package:akatabo/domain/spending.dart';
import 'package:akatabo/services/export/csv_writer.dart';
import 'package:akatabo/services/export/export_file.dart';
import 'package:akatabo/services/export/export_report.dart';
import 'package:akatabo/services/export/pdf_report.dart';
import 'package:akatabo/services/export/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

final _now = DateTime(2026, 11, 19, 9, 14);

final _categories = [
  categoryRow(id: DefaultIds.food, name: 'Food', monthlyBudget: 300000),
  categoryRow(id: DefaultIds.transport, name: 'Transport'),
  categoryRow(
    id: DefaultIds.bills,
    name: 'Bills',
    monthlyBudget: 100000,
    budgetCarriesOver: true,
    budgetSince: 20260901,
  ),
  categoryRow(id: DefaultIds.fees, name: 'Fees and tax', isSystem: true),
  categoryRow(id: DefaultIds.salary, name: 'Salary', kind: CategoryKind.income),
];

final _accounts = [
  accountRow(id: DefaultIds.mtn, name: 'MTN MoMo'),
  accountRow(id: DefaultIds.cash, name: 'Cash', kind: AccountKind.cash, colourToken: 'acct-cash'),
];

/// A month of entries with each kind of row: money out with fee and tax, money in, and a
/// cash withdrawal (a transfer: only its fee and tax are money out).
final _rows = [
  txRow(
    id: 'a',
    amount: 45000,
    fee: 1000,
    tax: 225,
    description: 'Kikuubo market',
    note: 'Rice, beans',
    at: DateTime(2026, 11, 3, 18, 5),
  ),
  txRow(
    id: 'b',
    direction: Direction.moneyIn,
    amount: 900000,
    categoryId: DefaultIds.salary,
    description: 'Salary',
    at: DateTime(2026, 11, 1, 8),
  ),
  txRow(
    id: 'c',
    direction: Direction.transfer,
    amount: 200000,
    toAccountId: DefaultIds.cash,
    fee: 3500,
    tax: 1000,
    description: 'Withdraw',
    at: DateTime(2026, 11, 10, 12, 30),
  ),
  txRow(
    id: 'd',
    amount: 2000,
    categoryId: DefaultIds.transport,
    description: '=HYPERLINK("http://x","boda")',
    at: DateTime(2026, 11, 12, 7, 45),
  ),
  // Last month: outside This month, but it counts towards Bills' carry-over.
  txRow(id: 'e', amount: 60000, categoryId: DefaultIds.bills, at: DateTime(2026, 10, 15, 9)),
];

ExportReport _report({
  Period? period,
  ExportOptions options = const ExportOptions(),
  List<Transaction>? rows,
  PeriodCalculator calc = const PeriodCalculator(),
}) => buildExportReport(
  all: rows ?? _rows,
  categories: _categories,
  accounts: _accounts,
  period: period,
  calc: calc,
  options: options,
  now: _now,
);

List<List<String>> _parseCsv(Uint8List bytes) {
  final text = utf8.decode(bytes.sublist(3));
  // Good enough for these rows: quoted fields here hold no line breaks.
  return [
    for (final line in text.split('\r\n'))
      if (line.isNotEmpty) _splitCsvLine(line),
  ];
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        b.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString());
  return out;
}

void main() {
  const calc = PeriodCalculator();
  final november = calc.month(_now);

  group('CSV fields', () {
    test('cells that would start a formula are written as text', () {
      expect(csvField('=SUM(A1:A9)'), "'=SUM(A1:A9)");
      expect(csvField('+256 772 000000'), "'+256 772 000000");
      expect(csvField('-5 discount'), "'-5 discount");
      expect(csvField('@cmd'), "'@cmd");
      expect(csvField('\tTab first'), "'\tTab first");
      expect(csvField('Ordinary words'), 'Ordinary words');
      expect(csvField(''), '');
    });

    test('numbers are not escaped, even below zero', () {
      expect(csvField('-15000', isText: false), '-15000');
    });

    test('commas, quotes and line breaks are quoted, with quotes doubled', () {
      expect(csvField('Rice, beans'), '"Rice, beans"');
      expect(csvField('The "big" shop'), '"The ""big"" shop"');
      expect(csvField('Two\nlines'), '"Two\nlines"');
      expect(csvField('Carriage\rreturn'), '"Carriage\rreturn"');
      expect(csvField('=1,2'), '"\'=1,2"');
    });
  });

  group('the CSV file', () {
    test('starts with the UTF-8 byte order mark and keeps non-English letters', () {
      final rows = [txRow(id: 'z', description: 'Café Ssebaggala', at: DateTime(2026, 11, 5))];
      final bytes = buildCsv(_report(period: november, rows: rows));
      expect(bytes.sublist(0, 3), csvBom);
      expect(utf8.decode(bytes.sublist(3)), contains('Café Ssebaggala'));
    });

    test('one row per entry in the period, oldest first, with all options', () {
      final csv = _parseCsv(buildCsv(_report(period: november)));
      expect(csv.first, [
        'Date',
        'Type',
        'Description',
        'Category',
        'Account',
        'To account',
        'Amount',
        'Fee',
        'Tax',
        'Money out',
        'Money in',
      ]);
      final entries = csv.sublist(1, 5);
      expect(entries.map((r) => r[0]), [
        '2026-11-01 08:00',
        '2026-11-03 18:05',
        '2026-11-10 12:30',
        '2026-11-12 07:45',
      ]);
      // Money out includes the fee and tax; a withdrawal counts only its fee and tax.
      expect(entries[1].sublist(6), ['45000', '1000', '225', '46225', '0']);
      expect(entries[2].sublist(1, 7), [
        'Move money',
        'Withdraw',
        '',
        'MTN MoMo',
        'Cash',
        '200000',
      ]);
      expect(entries[2][9], '4500');
      expect(entries[3][2], '\'=HYPERLINK("http://x","boda")', reason: 'formula kept as text');
    });

    test('without the fee columns, money out still includes the fee and tax', () {
      final csv = _parseCsv(
        buildCsv(
          _report(
            period: november,
            options: const ExportOptions(feesColumn: false, categoryTotals: false),
          ),
        ),
      );
      expect(csv.first, isNot(contains('Fee')));
      expect(csv.first, isNot(contains('Note')));
      expect(csv.first.sublist(6), ['Amount', 'Money out', 'Money in']);
      expect(csv[2].sublist(6), ['45000', '46225', '0']);
      expect(csv.length, 5, reason: 'header and four entries, no category table');
    });

    test('notes come in their own last column when chosen', () {
      final csv = _parseCsv(
        buildCsv(
          _report(
            period: november,
            options: const ExportOptions(notes: true, categoryTotals: false),
          ),
        ),
      );
      expect(csv.first.last, 'Note');
      expect(csv[2].last, 'Rice, beans');
    });

    test('category totals follow the entries after an empty line, with their own header', () {
      final text = utf8.decode(buildCsv(_report(period: november)).sublist(3));
      final parts = text.split('\r\n\r\n');
      expect(parts, hasLength(2));
      expect(parts[1], startsWith('Category,Money out,Monthly budget,'));
      expect(text, endsWith('\r\n'));
    });

    test('with only category totals chosen, the file is that table', () {
      final csv = _parseCsv(
        buildCsv(_report(period: november, options: const ExportOptions(transactions: false))),
      );
      expect(csv.first.first, 'Category');
    });
  });

  group('periods and figures', () {
    test('"Month starts on" moves This month, and the file is named after its first month', () {
      const from25 = PeriodCalculator(monthStartsOn: 25);
      final p = exportPeriod(ExportRange.thisMonth, now: _now, calc: from25)!;
      final rows = [
        txRow(id: '1', at: DateTime(2026, 10, 24, 23, 59)),
        txRow(id: '2', at: DateTime(2026, 10, 25)),
        txRow(id: '3', at: DateTime(2026, 11, 24, 22)),
        txRow(id: '4', at: DateTime(2026, 11, 25)),
      ];
      expect(rowsIn(rows, p).map((t) => t.id), ['2', '3']);
      expect(periodLabel(p), '25 October to 24 November 2026');
      expect(exportFileName(p, ExportFormat.csv, now: _now), 'akatabo-2026-10.csv');
    });

    test('This year follows the month start too; All has no limit', () {
      const from25 = PeriodCalculator(monthStartsOn: 25);
      final year = exportPeriod(ExportRange.thisYear, now: _now, calc: from25)!;
      expect(year.startDay, 20260125);
      expect(exportPeriod(ExportRange.all, now: _now, calc: from25), isNull);
      expect(rowsIn(_rows, null), hasLength(_rows.length));
    });

    test('a custom range includes both of its days', () {
      final p = exportPeriod(
        ExportRange.custom,
        now: _now,
        calc: calc,
        customFirst: DateTime(2026, 11, 3),
        customLast: DateTime(2026, 11, 10),
      )!;
      expect(rowsIn(_rows, p).map((t) => t.id).toSet(), {'a', 'c'});
      expect(periodLabel(p), '3 November to 10 November 2026');
      expect(
        exportFileName(p, ExportFormat.excel, now: _now),
        'akatabo-2026-11-03-to-2026-11-10.xlsx',
      );
    });

    test('file names for a month, a year, all dates and one day', () {
      expect(exportFileName(november, ExportFormat.csv, now: _now), 'akatabo-2026-11.csv');
      expect(exportFileName(calc.year(_now), ExportFormat.pdf, now: _now), 'akatabo-2026.pdf');
      expect(exportFileName(null, ExportFormat.excel, now: _now), 'akatabo-all-2026-11-19.xlsx');
      final day = Period(DateTime(2026, 11, 19), DateTime(2026, 11, 20), PeriodKind.custom);
      expect(exportFileName(day, ExportFormat.csv, now: _now), 'akatabo-2026-11-19.csv');
      expect(periodLabel(november), 'November 2026');
      expect(periodLabel(calc.year(_now)), '2026');
      expect(periodLabel(null), 'All dates');
    });

    test('the totals are the domain totals for the period', () {
      final r = _report(period: november);
      final inMonth = _rows.where((t) => november.containsDay(t.localDay));
      expect(r.totals.moneyOut, totalsOf(inMonth).moneyOut);
      expect(r.totals.moneyOut, 46225 + 4500 + 2000);
      expect(r.totals.moneyIn, 900000);
      final split = feeSplitOf(inMonth, cashAccountIds: {DefaultIds.cash});
      expect(r.fees.total, split.total);
      expect(r.fees.withdrawing, 3500);
      expect(r.fees.sending, 1000);
    });

    test('category lines use the domain split, budgets as Budgets shows them', () {
      final r = _report(period: november);
      final byName = {for (final l in r.categories) l.name: l};
      expect(byName['Food']!.moneyOut, 45000);
      expect(byName['Food']!.budgetThisPeriod, 300000);
      expect(byName['Food']!.left, 255000);
      expect(byName['Fees and tax']!.moneyOut, 1000 + 225 + 3500 + 1000);
      expect(byName['Fees and tax']!.monthlyBudget, isNull);
      // Bills: nothing spent this month, but a budget, with 40,000 carried from October.
      expect(byName['Bills']!.moneyOut, 0);
      expect(byName['Bills']!.budgetThisPeriod, 140000);
      expect(byName.containsKey('Salary'), isFalse, reason: 'money in is not a category total');
      expect(r.categories.first.name, 'Food', reason: 'biggest first');
      final sum = r.categories.fold<int>(0, (s, l) => s + l.moneyOut);
      expect(sum, r.totals.moneyOut, reason: 'the lines add up to money out');
    });

    test('budgets for a period that is not one month show only the monthly figure', () {
      final r = _report(period: calc.year(_now));
      expect(r.categoryTable().headers, ['Category', 'Money out', 'Monthly budget']);
      expect(r.categories.every((l) => l.budgetThisPeriod == null), isTrue);
    });
  });

  group('the Excel file', () {
    test('opens in Python: sheet names, a number cell and a date cell', () async {
      final bytes = buildExcel(_report(period: november));
      final dir = await Directory.systemTemp.createTemp('akatabo_xlsx');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/akatabo-2026-11.xlsx')..writeAsBytesSync(bytes);
      final script = File('${dir.path}/check.py')..writeAsStringSync(_pythonCheck);
      final result = await Process.run('python', ['-I', script.path, file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final out = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(out['sheets'], ['Transactions', 'Categories']);
      // Row 3 is 3 November: Amount (G3) a real number cell shown with thousands.
      expect(out['g3'], {'t': null, 's': '2', 'v': '45000'});
      // A3 is a date cell: 3 November 2026 18:05 as a serial (46329 is 3 Nov 2026).
      final a3 = out['a3'] as Map<String, dynamic>;
      expect(a3['t'], isNull);
      expect(a3['s'], '3');
      expect(double.parse(a3['v'] as String), closeTo(46329 + (18 * 60 + 5) / 1440, 1e-6));
      expect(out['b3'], 'Money out');
      expect(out['numFmt164'], 'yyyy-mm-dd hh:mm');
      expect(out['categoryHeader'], [
        'Category',
        'Money out',
        'Monthly budget',
        'Budget this month',
        'Left this month',
      ]);
    });

    test('column names and the date serial', () {
      expect(columnName(0), 'A');
      expect(columnName(25), 'Z');
      expect(columnName(26), 'AA');
      expect(columnName(27), 'AB');
      expect(excelSerial(DateTime(1900, 3)), 61);
      expect(excelSerial(DateTime(2026, 11, 19, 12)), 46345.5);
    });

    test('text that looks like XML is escaped and control characters dropped', () async {
      final rows = [txRow(id: 'x', description: 'A & B <shop> \u0001', at: DateTime(2026, 11, 2))];
      final bytes = buildExcel(
        _report(period: november, rows: rows, options: const ExportOptions(categoryTotals: false)),
      );
      expect(bytes.sublist(0, 2), [0x50, 0x4B], reason: 'a zip file');
      final dir = await Directory.systemTemp.createTemp('akatabo_xlsx');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/x.xlsx')..writeAsBytesSync(bytes);
      final script = File('${dir.path}/read.py')..writeAsStringSync(_pythonC3);
      final result = await Process.run('python', ['-I', script.path, file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String).trim(), jsonEncode('A & B <shop> '));
    });
  });

  group('the PDF report', () {
    final fonts = PdfFonts(
      regular: ByteData.sublistView(File(pdfRegularAsset).readAsBytesSync()),
      semiBold: ByteData.sublistView(File(pdfSemiBoldAsset).readAsBytesSync()),
    );

    int pages(Uint8List bytes) =>
        RegExp(r'/Type\s*/Page\b(?!s)').allMatches(latin1.decode(bytes)).length;

    test('builds a one-page report for a month', () async {
      final bytes = await buildPdfReport(_report(period: november), fonts, compress: false);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(pages(bytes), 1);
    });

    test('a long history runs over many pages, past the package default of 20', () async {
      final many = [
        for (var i = 0; i < 1200; i++)
          txRow(
            id: 'r$i',
            amount: 1000 + i,
            at: DateTime(2026).add(Duration(hours: i * 6)),
          ),
      ];
      final bytes = await buildPdfReport(
        _report(rows: many, options: const ExportOptions(notes: true)),
        fonts,
        compress: false,
      );
      expect(pages(bytes), greaterThan(20));
    });

    test('letters outside the font (an emoji, Luganda ŋ) do not stop the report', () async {
      final rows = [
        txRow(id: 'e', description: 'Lunch 🍕 at Ŋŋ café', note: 'ñ', at: DateTime(2026, 11, 2)),
      ];
      final bytes = await buildPdfReport(
        _report(period: november, rows: rows, options: const ExportOptions(notes: true)),
        fonts,
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('every format can be made on a background isolate', () async {
      final r = _report(period: november);
      for (final f in ExportFormat.values) {
        final bytes = await buildExportBytesInBackground(r, f, fonts);
        expect(bytes, isNotEmpty, reason: f.name);
      }
    });

    test('its headline figures are the domain totals', () {
      final r = _report(period: november);
      final h = pdfHeadline(r);
      expect(h.period, 'November 2026');
      expect(h.moneyOut, 'UGX 52,725');
      expect(h.moneyIn, 'UGX 900,000');
      expect(h.net, '847,275 more than went out');
      expect(h.fees, 'UGX 5,725');
      expect(h.feesLine, 'Fees and tax: sending money 1,000, withdrawing cash 3,500, tax 1,225.');
      expect(h.transactions, '4 transactions');
      expect(h.made, 'Made on 19 November 2026 at 09:14. Amounts are in Uganda shillings (UGX).');
    });

    test('tax from withdrawals only is named so', () {
      final rows = [
        txRow(
          id: 'w',
          direction: Direction.transfer,
          amount: 50000,
          toAccountId: DefaultIds.cash,
          tax: 250,
          at: DateTime(2026, 11, 4),
        ),
      ];
      expect(
        pdfHeadline(_report(period: november, rows: rows)).feesLine,
        'Fees and tax: tax on withdrawals 250.',
      );
    });
  });
}

/// Prints cell C2 (the first entry's description) of the first sheet as JSON.
const _pythonC3 = r'''
import json, sys, zipfile
import xml.etree.ElementTree as ET
m = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read("xl/worksheets/sheet1.xml"))
for c in root.iter(m + "c"):
    if c.get("r") == "C2":
        print(json.dumps(c.find(m + "is/" + m + "t").text))
''';

/// Reads the workbook with Python's standard library only, as a spreadsheet would: the zip, the
/// workbook's sheet names, and two cells of the first sheet.
const _pythonCheck = r'''
import json, sys, zipfile
import xml.etree.ElementTree as ET
ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
z = zipfile.ZipFile(sys.argv[1])
assert z.testzip() is None
wb = ET.fromstring(z.read("xl/workbook.xml"))
sheets = [s.get("name") for s in wb.find("m:sheets", ns)]
def cells(path):
    root = ET.fromstring(z.read(path))
    out = {}
    for c in root.iter("{%s}c" % ns["m"]):
        v = c.find("m:v", ns)
        t = c.find("m:is/m:t", ns)
        out[c.get("r")] = {"t": c.get("t"), "s": c.get("s"), "v": v.text if v is not None else None,
                           "text": t.text if t is not None else None}
    return out
one = cells("xl/worksheets/sheet1.xml")
two = cells("xl/worksheets/sheet2.xml")
styles = ET.fromstring(z.read("xl/styles.xml"))
fmt = {f.get("numFmtId"): f.get("formatCode") for f in styles.iter("{%s}numFmt" % ns["m"])}
g3 = one["G3"]
print(json.dumps({
    "sheets": sheets,
    "g3": {"t": g3["t"], "s": g3["s"], "v": g3["v"]},
    "a3": one["A3"],
    "b3": one["B3"]["text"],
    "numFmt164": fmt.get("164"),
    "categoryHeader": [two[r]["text"] for r in ("A1", "B1", "C1", "D1", "E1")],
}))
''';
