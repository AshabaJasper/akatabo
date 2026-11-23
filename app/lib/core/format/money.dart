/// How money and percentages are written, from DESIGN_SYSTEM.md > Writing.
library;

import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##0', 'en');

/// `1,284,000`. Whole shillings with comma separators.
String formatAmount(int shillings) => _grouped.format(shillings);

/// `UGX 1,284,000`.
String formatUgx(int shillings) => 'UGX ${formatAmount(shillings)}';

/// `- 45,000` for money out, `+ 250,000` for money in. Colour never carries direction alone.
String formatSigned(int shillings, {required bool moneyIn}) =>
    '${moneyIn ? '+' : '-'} ${formatAmount(shillings.abs())}';

/// "How amounts are written" in General settings: in full, or short like `1.28M`. Only the
/// large main figure on a screen follows it; rows, receipts and exports stay in full.
enum AmountStyle { full, short }

/// A screen's main figure in [style]: `UGX 1,284,000` or `UGX 1.28M`.
String formatHeadline(int shillings, AmountStyle style) =>
    style == AmountStyle.short ? 'UGX ${formatShort(shillings)}' : formatUgx(shillings);

/// Short form for chart labels and stat tiles only: `1.83M`, `298k`, `950`.
String formatShort(int shillings) {
  final sign = shillings < 0 ? '-' : '';
  final v = shillings.abs();
  if (v >= 999500) {
    return '$sign${_trim((v / 1000000).toStringAsFixed(2))}M';
  }
  if (v >= 1000) return '$sign${(v / 1000).round()}k';
  return '$sign$v';
}

/// A percentage: whole unless under 10, then one decimal. `32%`, `8.5%`, `4.0%`.
/// Takes the size of the share or change; callers say "up" or "down" in words.
String formatPercent(double percent) {
  final p = percent.abs();
  final oneDecimal = (p * 10).round() / 10;
  if (oneDecimal >= 10) return '${p.round()}%';
  return '${oneDecimal.toStringAsFixed(1)}%';
}

/// A share of a total as a percentage, safe when the total is zero.
double shareOf(int part, int total) => total == 0 ? 0 : part * 100 / total;

String _trim(String fixed) =>
    fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
