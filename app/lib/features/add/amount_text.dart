import 'package:flutter/services.dart';

import '../../core/format/money.dart';

/// The shillings in what the person typed: `45,000` becomes 45000. Anything that is not a
/// digit is ignored, and an empty field is zero.
int parseAmount(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty) return 0;
  // Fourteen digits is far beyond any real amount and stops int overflow on a pasted number.
  final capped = digits.length > 14 ? digits.substring(0, 14) : digits;
  return int.parse(capped);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// Groups digits in thousands as the person types.
///
/// The cursor keeps its place among the digits: as many digits stay to its right after the
/// commas move as were to its right in what was typed. Editing the middle of `45,000` leaves
/// the cursor where the person is typing instead of throwing it to the end.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final amount = parseAmount(newValue.text);
    if (amount == 0) return const TextEditingValue();
    final formatted = formatAmount(amount);

    final typed = newValue.text;
    final end = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, typed.length)
        : typed.length;
    var digitsRight = 0;
    for (var i = end; i < typed.length; i++) {
      if (_isDigit(typed.codeUnitAt(i))) digitsRight++;
    }

    var offset = formatted.length;
    var seen = 0;
    while (seen < digitsRight && offset > 0) {
      offset--;
      if (_isDigit(formatted.codeUnitAt(offset))) seen++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Keeps a decimal point out of a whole-shilling field. Shillings have no cents, and dropping
/// the point after the fact joined the digits either side (5000.5 became 50,005).
///
/// A point typed on the keyboard is refused. A pasted figure with cents at the end, such as
/// "50,000.00" from a bank SMS, keeps its shillings and loses the cents. Any other point, as
/// in "1.500" where it groups thousands, is refused, since cutting there would change the
/// amount. The grouping commas are written by [ThousandsFormatter].
class NoDecimalPointFormatter extends TextInputFormatter {
  const NoDecimalPointFormatter();

  /// A point with at most two digits after it, ending the figure: the cents.
  static final _cents = RegExp(r'\.\d{0,2}(?!\d)');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (!text.contains('.')) return newValue;
    // How many characters this edit put in: one for a key press, more for a paste.
    final sel = oldValue.selection;
    final replaced = sel.isValid ? sel.end - sel.start : 0;
    final inserted = text.length - (oldValue.text.length - replaced);
    if (inserted > 1 && _cents.allMatches(text).length == 1) {
      final shillings = text.replaceFirst(_cents, '');
      if (!shillings.contains('.')) {
        return TextEditingValue(
          text: shillings,
          selection: TextSelection.collapsed(offset: shillings.length),
        );
      }
    }
    return oldValue;
  }
}
