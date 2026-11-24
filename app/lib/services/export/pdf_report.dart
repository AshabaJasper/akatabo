/// The PDF report: title, period, the totals, fees and tax, category totals with budgets, and
/// the transactions, in Geist. The `pdf` package reads static fonts only, so the report uses
/// Geist Regular and SemiBold cut from the app's variable font (assets/fonts).
///
/// This is page layout, not a screen: sizes are in PDF points. Every colour comes from the
/// light tokens, since a printed page is light.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format/money.dart';
import '../../core/theme/tokens.g.dart';
import '../../data/db/app_database.dart';
import '../../domain/spending.dart';
import 'export_report.dart';

/// The two static Geist faces, as bytes from the asset bundle (or from disk in tests).
class PdfFonts {
  const PdfFonts({required this.regular, required this.semiBold, this.logo});
  final ByteData regular;
  final ByteData semiBold;

  /// The Akatabo logo as PNG bytes for the report header. Without it the header is the word.
  final Uint8List? logo;
}

const pdfRegularAsset = 'assets/fonts/Geist-Regular.ttf';
const pdfSemiBoldAsset = 'assets/fonts/Geist-SemiBold.ttf';
const pdfLogoAsset = 'assets/brand/pdf-logo.png';

PdfColor _pdf(int argb) => PdfColor.fromInt(argb);

final _ink = _pdf(akLightTokens.ink.toARGB32());
final _muted = _pdf(akLightTokens.inkMuted.toARGB32());
final _line = _pdf(akLightTokens.line.toARGB32());
final _sunk = _pdf(akLightTokens.surfaceSunk.toARGB32());
final _brandText = _pdf(akLightTokens.brandText.toARGB32());

final _made = DateFormat("d MMMM yyyy 'at' HH:mm");
final _rowDate = DateFormat('d MMM yyyy');

/// A page holds about 40 rows; this lets a report of every entry run long instead of stopping
/// at the package's default of 20 pages. 10,000 pages is far beyond any person's history.
const _maxPages = 10000;

/// The words and figures at the top of the report. Kept apart from the layout so tests can
/// check them against the domain rules: text inside a PDF is stored as glyph numbers.
class PdfHeadline {
  const PdfHeadline({
    required this.period,
    required this.made,
    required this.moneyOut,
    required this.moneyIn,
    required this.net,
    required this.fees,
    required this.feesLine,
    required this.transactions,
  });

  final String period;
  final String made;
  final String moneyOut;
  final String moneyIn;
  final String net;
  final String fees;
  final String feesLine;
  final String transactions;
}

PdfHeadline pdfHeadline(ExportReport r) {
  final net = r.totals.net;
  return PdfHeadline(
    period: r.periodLabel,
    made: 'Made on ${_made.format(r.made)}. Amounts are in Uganda shillings (UGX).',
    moneyOut: formatUgx(r.totals.moneyOut),
    moneyIn: formatUgx(r.totals.moneyIn),
    net: net >= 0
        ? '${formatAmount(net)} more than went out'
        : '${formatAmount(-net)} less than went out',
    fees: formatUgx(r.fees.total),
    feesLine: _feesLine(r),
    transactions: r.rows.length == 1 ? '1 transaction' : '${r.rows.length} transactions',
  );
}

/// The report for [report] as PDF bytes. [compress] is switched off only by tests that read
/// the page objects.
Future<Uint8List> buildPdfReport(ExportReport report, PdfFonts fonts, {bool compress = true}) {
  final h = pdfHeadline(report);
  final regular = pw.Font.ttf(fonts.regular);
  final semiBold = pw.Font.ttf(fonts.semiBold);
  final doc = pw.Document(
    title: 'Akatabo report, ${report.periodLabel}',
    creator: 'Akatabo',
    compress: compress,
    theme: pw.ThemeData.withFont(base: regular, bold: semiBold),
  );

  pw.TextStyle style(double size, {bool strong = false, PdfColor? colour}) => pw.TextStyle(
    font: strong ? semiBold : regular,
    fontSize: size,
    color: colour ?? _ink,
    lineSpacing: size * 0.25,
  );

  final o = report.options;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
      maxPages: _maxPages,
      footer: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Akatabo, ${report.periodLabel}', style: style(8, colour: _muted)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: style(8, colour: _muted)),
          ],
        ),
      ),
      build: (ctx) => [
        if (fonts.logo case final logo?)
          pw.Image(pw.MemoryImage(logo), height: 22, alignment: pw.Alignment.centerLeft)
        else
          pw.Text('Akatabo', style: style(10, strong: true, colour: _brandText)),
        pw.SizedBox(height: 6),
        pw.Text('Money report', style: style(22, strong: true)),
        pw.SizedBox(height: 2),
        pw.Text(h.period, style: style(14)),
        pw.SizedBox(height: 4),
        pw.Text(h.made, style: style(9, colour: _muted)),
        pw.SizedBox(height: 18),
        _totals(h, style),
        pw.SizedBox(height: 8),
        pw.Text(h.feesLine, style: style(9, colour: _muted)),
        if (o.categoryTotals) ...[
          pw.SizedBox(height: 22),
          pw.Text('Where the money went', style: style(13, strong: true)),
          pw.SizedBox(height: 6),
          _table(report.categoryTable(), style, numericFrom: 1),
          if (!report.isOneMonth && report.categories.any((l) => l.monthlyBudget != null))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                'Budgets are set per month, so this period shows each monthly budget as set.',
                style: style(8, colour: _muted),
              ),
            ),
        ],
        if (o.transactions) ...[
          pw.SizedBox(height: 22),
          pw.Text(h.transactions, style: style(13, strong: true)),
          pw.SizedBox(height: 6),
          _transactions(report, style),
        ],
      ],
    ),
  );
  return doc.save();
}

typedef _Style = pw.TextStyle Function(double size, {bool strong, PdfColor? colour});

pw.Widget _totals(PdfHeadline h, _Style style) {
  pw.Widget figure(String label, String amount, String note) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _sunk, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: style(9, colour: _muted)),
          pw.SizedBox(height: 4),
          pw.Text(amount, style: style(14, strong: true)),
          pw.SizedBox(height: 2),
          pw.Text(note, style: style(8, colour: _muted)),
        ],
      ),
    ),
  );
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      figure('Money out', h.moneyOut, 'Including fees and tax'),
      pw.SizedBox(width: 8),
      figure('Money in', h.moneyIn, h.net),
      pw.SizedBox(width: 8),
      figure('Fees and tax', h.fees, 'Part of money out'),
    ],
  );
}

/// "Sending money 12,000 (4), withdrawing cash 3,000 (1), tax 2,500." with the tax named "tax
/// on withdrawals" only while all of it came from withdrawals, as Fees and tax names it.
String _feesLine(ExportReport r) {
  final f = r.fees;
  if (f.total == 0) return 'No fees or tax in this period.';
  final parts = [
    if (f.sending > 0) 'sending money ${formatAmount(f.sending)}',
    if (f.withdrawing > 0) 'withdrawing cash ${formatAmount(f.withdrawing)}',
    if (f.tax > 0)
      '${f.taxIsAllFromWithdrawals ? 'tax on withdrawals' : 'tax'} ${formatAmount(f.tax)}',
  ];
  final text = parts.join(', ');
  return 'Fees and tax: $text.';
}

String _plain(ExportCell c) => switch (c.value) {
  null => '',
  final int n => formatAmount(n),
  final DateTime d => _rowDate.format(d),
  final Object s => '$s',
};

pw.Widget _table(ExportTable t, _Style style, {required int numericFrom}) =>
    pw.TableHelper.fromTextArray(
      headers: t.headers,
      data: [
        for (final row in t.rows) [for (final c in row) _plain(c)],
      ],
      border: null,
      headerStyle: style(8.5, strong: true, colour: _muted),
      cellStyle: style(9),
      headerDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.75)),
      ),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        for (var i = numericFrom; i < t.headers.length; i++) i: pw.Alignment.centerRight,
      },
      headerAlignments: {
        for (var i = numericFrom; i < t.headers.length; i++) i: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    );

/// The transactions table, narrower than the spreadsheet: a date, what it was (with its note
/// under it when notes are chosen), category, account, then the figures.
pw.Widget _transactions(ExportReport r, _Style style) {
  final o = r.options;
  final headers = [
    'Date',
    'Description',
    'Category',
    'Account',
    if (o.feesColumn) 'Fee and tax',
    'Money out',
    'Money in',
  ];
  String description(Transaction t) {
    final words = t.description.isEmpty ? ExportReport.typeOf(t) : t.description;
    final note = o.notes ? t.note : null;
    return note == null || note.isEmpty ? words : '$words\n$note';
  }

  String account(Transaction t) => t.toAccountId == null
      ? r.accountOf(t.accountId)
      : '${r.accountOf(t.accountId)} to ${r.accountOf(t.toAccountId)}';

  String amount(int n) => n == 0 ? '' : formatAmount(n);

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: [
      for (final t in r.rows)
        [
          _rowDate.format(t.occurredAt),
          description(t),
          r.categoryOf(t),
          account(t),
          if (o.feesColumn) amount(t.fee + t.tax),
          amount(moneyOutOf(t)),
          amount(moneyInOf(t)),
        ],
    ],
    border: null,
    headerStyle: style(8.5, strong: true, colour: _muted),
    cellStyle: style(8.5),
    headerDecoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.75)),
    ),
    rowDecoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(62),
      1: const pw.FlexColumnWidth(2.4),
      2: const pw.FlexColumnWidth(1.3),
      3: const pw.FlexColumnWidth(1.4),
    },
    headerAlignment: pw.Alignment.centerLeft,
    cellAlignment: pw.Alignment.centerLeft,
    cellAlignments: {for (var i = 4; i < headers.length; i++) i: pw.Alignment.centerRight},
    headerAlignments: {for (var i = 4; i < headers.length; i++) i: pw.Alignment.centerRight},
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
  );
}
