/// What an export holds, worked out once from stored rows so the CSV, Excel and PDF files all
/// show the same figures. No Flutter: tests build reports from plain rows.
///
/// Every figure comes from the domain rules (`domain/spending.dart`, `domain/fees.dart`,
/// `domain/budget.dart`): money out includes fees and tax, a transfer counts only its fee and
/// tax, and a category's fees and tax sit in the reserved Fees and tax category.
library;

import 'package:intl/intl.dart';

import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/seed/default_data.dart';
import '../../domain/budget.dart';
import '../../domain/fees.dart';
import '../../domain/spending.dart';

/// The three file kinds on the Format control.
enum ExportFormat {
  csv('CSV', 'csv', 'text/csv'),
  excel('Excel', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('PDF report', 'pdf', 'application/pdf');

  const ExportFormat(this.label, this.extension, this.mimeType);
  final String label;
  final String extension;
  final String mimeType;
}

/// The four choices on the Period control.
enum ExportRange {
  thisMonth('This month'),
  thisYear('This year'),
  all('All'),
  custom('Custom');

  const ExportRange(this.label);
  final String label;
}

/// What to include, as the four tick boxes draw it.
class ExportOptions {
  const ExportOptions({
    this.transactions = true,
    this.feesColumn = true,
    this.categoryTotals = true,
    this.notes = false,
  });

  /// One row per entry.
  final bool transactions;

  /// Fee and tax get their own columns beside the amount. Off, they are still inside
  /// "Money out", so the totals are the same either way.
  final bool feesColumn;

  /// A table of money out by category with each budget.
  final bool categoryTotals;

  /// The note written on an entry.
  final bool notes;

  ExportOptions copyWith({
    bool? transactions,
    bool? feesColumn,
    bool? categoryTotals,
    bool? notes,
  }) => ExportOptions(
    transactions: transactions ?? this.transactions,
    feesColumn: feesColumn ?? this.feesColumn,
    categoryTotals: categoryTotals ?? this.categoryTotals,
    notes: notes ?? this.notes,
  );
}

/// The days a [range] covers, from "Month starts on" through [calc]. Null for all dates.
/// [customFirst] and [customLast] are both included and are needed for [ExportRange.custom].
Period? exportPeriod(
  ExportRange range, {
  required DateTime now,
  required PeriodCalculator calc,
  DateTime? customFirst,
  DateTime? customLast,
}) => switch (range) {
  ExportRange.thisMonth => calc.month(now),
  ExportRange.thisYear => calc.year(now),
  ExportRange.all => null,
  ExportRange.custom => Period(
    customFirst ?? (throw ArgumentError('A custom range needs its first day')),
    addDays(customLast ?? (throw ArgumentError('A custom range needs its last day')), 1),
    PeriodKind.custom,
  ),
};

/// The entries in [period] (all of them when null).
List<Transaction> rowsIn(Iterable<Transaction> rows, Period? period) =>
    period == null ? rows.toList() : rows.where((t) => period.containsDay(t.localDay)).toList();

final _monthName = DateFormat('MMMM yyyy');
final _dayMonth = DateFormat('d MMMM');
final _dayMonthYear = DateFormat('d MMMM yyyy');

/// The period in words: "November 2026" for a month that starts on the 1st, "2026" for a
/// calendar year, otherwise its first and last day, "25 October to 24 November 2026".
String periodLabel(Period? period) {
  if (period == null) return 'All dates';
  final first = period.start;
  final last = period.lastDate;
  if (period.kind == PeriodKind.month && first.day == 1) {
    return _monthName.format(first);
  }
  if (period.kind == PeriodKind.year && first.day == 1 && first.month == 1) {
    return '${first.year}';
  }
  if (first == last) return _dayMonthYear.format(first);
  final from = first.year == last.year ? _dayMonth.format(first) : _dayMonthYear.format(first);
  return '$from to ${_dayMonthYear.format(last)}';
}

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A short, safe file name: `akatabo-2026-11.csv` for a month, `akatabo-2026.xlsx` for a year,
/// `akatabo-2026-11-03-to-2026-11-15.pdf` for a custom range, and `akatabo-all-2026-11-20.csv`
/// (the day it was made) for all dates. Only letters, digits and hyphens, so every file
/// system and share target accepts it.
String exportFileName(Period? period, ExportFormat format, {required DateTime now}) {
  final String stem;
  if (period == null) {
    stem = 'all-${_ymd(now)}';
  } else if (period.kind == PeriodKind.month) {
    stem = DateFormat('yyyy-MM').format(period.start);
  } else if (period.kind == PeriodKind.year) {
    stem = '${period.start.year}';
  } else if (period.lengthInDays == 1) {
    stem = _ymd(period.start);
  } else {
    stem = '${_ymd(period.start)}-to-${_ymd(period.lastDate)}';
  }
  return 'akatabo-$stem.${format.extension}';
}

/// One cell of an exported table: text, a whole number of shillings, a moment, or nothing.
/// The CSV writes each as text; the Excel writer keeps numbers and dates as real cells.
class ExportCell {
  const ExportCell.text(String this.value);
  const ExportCell.amount(int this.value);
  const ExportCell.date(DateTime this.value);
  const ExportCell.empty() : value = null;

  final Object? value;
}

/// A table with one header row: the transactions, or the category totals.
class ExportTable {
  const ExportTable({required this.name, required this.headers, required this.rows});

  /// The sheet name in Excel and the heading in the PDF.
  final String name;
  final List<String> headers;
  final List<List<ExportCell>> rows;
}

/// One category's line in the category table.
class CategoryLine {
  const CategoryLine({
    required this.name,
    required this.moneyOut,
    this.monthlyBudget,
    this.budgetThisPeriod,
  });

  final String name;

  /// Money out in the category over the period. Fees and tax is its own line.
  final int moneyOut;

  /// The budget as set, per month. Null without one.
  final int? monthlyBudget;

  /// For a one-month period: the budget for that month, with carry-over as Budgets shows it.
  /// Null for other periods, since budgets are monthly.
  final int? budgetThisPeriod;

  /// What is left of [budgetThisPeriod]; negative when it was overspent.
  int? get left => budgetThisPeriod == null ? null : budgetThisPeriod! - moneyOut;
}

/// Everything an export needs, worked out once.
class ExportReport {
  const ExportReport({
    required this.period,
    required this.periodLabel,
    required this.made,
    required this.options,
    required this.rows,
    required this.totals,
    required this.fees,
    required this.categories,
    required this.categoryNames,
    required this.accountNames,
  });

  /// Null for all dates.
  final Period? period;
  final String periodLabel;

  /// When the file was made, for the PDF's footer and the all-dates file name.
  final DateTime made;
  final ExportOptions options;

  /// The entries in the period, oldest first.
  final List<Transaction> rows;
  final PeriodTotals totals;
  final FeeSplit fees;

  /// Biggest first.
  final List<CategoryLine> categories;
  final Map<String, String> categoryNames;
  final Map<String, String> accountNames;

  bool get isOneMonth => period?.kind == PeriodKind.month;

  /// The words for an entry's direction, as Add names them.
  static String typeOf(Transaction t) => switch (t.direction) {
    Direction.moneyOut => 'Money out',
    Direction.moneyIn => 'Money in',
    Direction.transfer => 'Move money',
  };

  String categoryOf(Transaction t) => t.direction == Direction.transfer
      ? ''
      : categoryNames[t.categoryId ?? DefaultIds.other] ?? 'Other';

  String accountOf(String? id) => id == null ? '' : accountNames[id] ?? '';

  /// The transactions table. Columns follow [options]: Fee and Tax only when they have their
  /// own column, Note only when notes are included. "Money out" always includes the fee and
  /// tax, so the columns add up to the totals whichever options are on.
  ExportTable transactionTable() => ExportTable(
    name: 'Transactions',
    headers: [
      'Date',
      'Type',
      'Description',
      'Category',
      'Account',
      'To account',
      'Amount',
      if (options.feesColumn) ...['Fee', 'Tax'],
      'Money out',
      'Money in',
      if (options.notes) 'Note',
    ],
    rows: [
      for (final t in rows)
        [
          ExportCell.date(t.occurredAt),
          ExportCell.text(typeOf(t)),
          ExportCell.text(t.description),
          ExportCell.text(categoryOf(t)),
          ExportCell.text(accountOf(t.accountId)),
          ExportCell.text(accountOf(t.toAccountId)),
          ExportCell.amount(t.amount),
          if (options.feesColumn) ...[ExportCell.amount(t.fee), ExportCell.amount(t.tax)],
          ExportCell.amount(moneyOutOf(t)),
          ExportCell.amount(moneyInOf(t)),
          if (options.notes) ExportCell.text(t.note ?? ''),
        ],
    ],
  );

  /// The category table: money out per category, its monthly budget, and for a one-month
  /// period that month's budget and what is left. A last "Total" line adds the money out.
  ExportTable categoryTable() => ExportTable(
    name: 'Categories',
    headers: [
      'Category',
      'Money out',
      'Monthly budget',
      if (isOneMonth) ...['Budget this month', 'Left this month'],
    ],
    rows: [
      for (final l in categories)
        [
          ExportCell.text(l.name),
          ExportCell.amount(l.moneyOut),
          l.monthlyBudget == null ? const ExportCell.empty() : ExportCell.amount(l.monthlyBudget!),
          if (isOneMonth) ...[
            l.budgetThisPeriod == null
                ? const ExportCell.empty()
                : ExportCell.amount(l.budgetThisPeriod!),
            l.left == null ? const ExportCell.empty() : ExportCell.amount(l.left!),
          ],
        ],
      [
        const ExportCell.text('Total'),
        ExportCell.amount(totals.moneyOut),
        const ExportCell.empty(),
        if (isOneMonth) ...[const ExportCell.empty(), const ExportCell.empty()],
      ],
    ],
  );
}

/// Builds the report for [period] from every stored entry. [all] must hold every entry (not
/// only the period's), because a month's carry-over reads the month before it.
ExportReport buildExportReport({
  required List<Transaction> all,
  required List<Category> categories,
  required List<Account> accounts,
  required Period? period,
  required PeriodCalculator calc,
  required ExportOptions options,
  required DateTime now,
}) {
  final rows = rowsIn(all, period)
    ..sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final cashIds = {
    for (final a in accounts)
      if (a.kind == AccountKind.cash) a.id,
  };
  final byCategory = moneyOutByCategory(rows);
  final isOneMonth = period?.kind == PeriodKind.month;
  final previous = isOneMonth ? calc.previous(period!) : null;
  final spentBefore = previous == null
      ? const <String, int>{}
      : moneyOutByCategory(rowsIn(all, previous));

  final lines = <CategoryLine>[];
  for (final cat in categories) {
    if (cat.kind != CategoryKind.spending) continue;
    final spent = byCategory[cat.id] ?? 0;
    final base = cat.isSystem ? null : cat.monthlyBudget;
    final hasBudget = base != null && base > 0;
    if (spent == 0 && !(hasBudget && !cat.hidden)) continue;
    lines.add(
      CategoryLine(
        name: cat.name,
        moneyOut: spent,
        monthlyBudget: hasBudget ? base : null,
        // The same figure Budgets shows for the month, carry-over included.
        budgetThisPeriod: hasBudget && previous != null
            ? effectiveBudget(
                base: base,
                carriesOver:
                    cat.budgetCarriesOver &&
                    carryApplies(
                      budgetSince: cat.budgetSince,
                      previousMonthStartDay: previous.startDay,
                    ),
                previousSpent: spentBefore[cat.id] ?? 0,
              )
            : null,
      ),
    );
  }
  // An entry whose category no longer exists still counts, as Other does on Home.
  final known = {for (final c in categories) c.id};
  final orphaned = byCategory.entries
      .where((e) => !known.contains(e.key))
      .fold<int>(0, (sum, e) => sum + e.value);
  if (orphaned > 0) lines.add(CategoryLine(name: 'Other', moneyOut: orphaned));
  lines.sort((a, b) {
    final bySpend = b.moneyOut.compareTo(a.moneyOut);
    return bySpend != 0 ? bySpend : a.name.compareTo(b.name);
  });

  return ExportReport(
    period: period,
    periodLabel: periodLabel(period),
    made: now,
    options: options,
    rows: rows,
    totals: totalsOf(rows),
    fees: feeSplitOf(rows, cashAccountIds: cashIds),
    categories: lines,
    categoryNames: {for (final c in categories) c.id: c.name},
    accountNames: {for (final a in accounts) a.id: a.name},
  );
}
