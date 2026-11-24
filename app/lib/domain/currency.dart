import '../core/format/money.dart';

/// Foreign money: converting a typed amount into whole shillings, with the rates typed by the
/// person. Everything here is integer arithmetic, so no rounding error creeps in.
///
/// Units:
/// - A foreign amount is kept in hundredths of its unit (cents, for dollars): 100.50 USD is
///   `10050`. Currencies with no small unit are written the same way, with `00` at the end.
/// - A rate is shillings per one unit, times a million, so 3,720 UGX per USD is `3720000000`.
/// - Shillings are whole. A conversion rounds half up to the whole shilling.

/// Hundredths per unit, and micros per shilling.
const _centsPerUnit = 100;
const _microsPerUnit = 1000000;

/// Decimals a rate keeps, typed and shown: a micro of a shilling.
const rateDecimals = 6;

/// The largest whole rate and whole amount typed, in units.
const _maxRateWhole = 10000000;
const _maxAmountWhole = 10000000000;

/// Currencies offered first. Any three-letter ISO code can be typed in as well.
const commonCurrencies = ['USD', 'KES', 'TZS', 'RWF', 'EUR', 'GBP', 'CNY', 'AED'];

/// Whether [code] looks like an ISO 4217 code: three capital letters. UGX is not foreign.
bool isForeignCode(String code) => RegExp(r'^[A-Z]{3}$').hasMatch(code) && code != 'UGX';

/// Shillings for [foreignMinor] hundredths at [rateMicros] shillings per unit, rounded half up
/// to the whole shilling. Negative amounts round away from zero, so a reversal matches its
/// original.
int ugxFor({required int foreignMinor, required int rateMicros}) {
  // BigInt: the product of a large amount and a rate can pass 64 bits, which would wrap
  // silently into a wrong figure.
  final numerator = BigInt.from(foreignMinor) * BigInt.from(rateMicros);
  final divisor = BigInt.from(_centsPerUnit) * BigInt.from(_microsPerUnit);
  final half = divisor ~/ BigInt.two;
  // Round half up: floor((n + d/2) / d) for n >= 0, and the mirror image below zero.
  final rounded = numerator >= BigInt.zero
      ? (numerator + half) ~/ divisor
      : -((-numerator + half) ~/ divisor);
  return rounded.toInt();
}

/// The rate typed as text ("3,720" or "3720.5") in micros, or null when it is not a rate above
/// zero. Commas and spaces are allowed; at most six decimals count.
int? parseRateMicros(String text) {
  final cleaned = text.replaceAll(RegExp(r'[,\s]'), '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,6}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  // Ten million shillings a unit is far beyond any real rate; the cap keeps the arithmetic
  // well inside 64 bits.
  if (whole == null || whole > _maxRateWhole) return null;
  final frac = (match.group(2) ?? '').padRight(6, '0');
  final micros = whole * _microsPerUnit + int.parse(frac.isEmpty ? '0' : frac);
  return micros > 0 ? micros : null;
}

/// A rate in words for a field: "3,720" or "3,720.5". Every decimal the rate holds is
/// shown, so a rate opened in a field and saved again is unchanged.
String formatRate(int rateMicros) {
  final whole = rateMicros ~/ _microsPerUnit;
  final frac = (rateMicros % _microsPerUnit).toString().padLeft(rateDecimals, '0');
  final trimmed = frac.replaceFirst(RegExp(r'0+$'), '');
  final tail = trimmed.isEmpty ? '' : '.$trimmed';
  return '${formatAmount(whole)}$tail';
}

/// The typed amount ("100", "100.5", "1,000.50") in hundredths, or null when it is not an
/// amount above zero. Commas here are thousands separators; the amount field turns a typed
/// decimal comma into a full stop before this reads it.
int? parseForeignMinor(String text) {
  final cleaned = text.replaceAll(RegExp(r'[,\s]'), '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  // Ten billion units: far beyond any real payment.
  if (whole == null || whole > _maxAmountWhole) return null;
  final frac = (match.group(2) ?? '').padRight(2, '0');
  final minor = whole * _centsPerUnit + int.parse(frac.isEmpty ? '0' : frac);
  return minor > 0 ? minor : null;
}

/// A foreign amount in words: "USD 100", or "USD 100.50" when it has cents.
String formatForeign(String code, int minor) => '$code ${foreignFieldText(minor)}';

/// A foreign amount as the amount field shows it: "100", or "1,000.50" with cents.
String foreignFieldText(int minor) {
  final whole = minor ~/ _centsPerUnit;
  final cents = minor % _centsPerUnit;
  final tail = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '${formatAmount(whole)}$tail';
}

/// The line under the amount field: "= UGX 372,000".
String ugxLine(int ugx) => formatUgx(ugx);

/// A foreign amount as a plain number for a spreadsheet: "100.50", never grouped.
String plainForeign(int minor) {
  final whole = minor ~/ _centsPerUnit;
  final cents = minor % _centsPerUnit;
  return cents == 0 ? '$whole' : '$whole.${cents.toString().padLeft(2, '0')}';
}

/// A rate as a plain number for a spreadsheet: "3720" or "3720.5", never grouped.
String plainRate(int rateMicros) {
  final whole = rateMicros ~/ _microsPerUnit;
  final frac = (rateMicros % _microsPerUnit)
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}

/// The foreign side of an entry: "USD 100 at 3,720", or "USD 100.50 at 3,720.5".
String foreignSummary(String code, int minor, int rateMicros) =>
    '${formatForeign(code, minor)} at ${formatRate(rateMicros)}';
