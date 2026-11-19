import 'package:akatabo/features/add/amount_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the shillings from what was typed', () {
    expect(parseAmount('45,000'), 45000);
    expect(parseAmount('UGX 1,284,000'), 1284000);
    expect(parseAmount(''), 0);
    expect(parseAmount('abc'), 0);
  });

  test('a pasted number cannot overflow', () {
    expect(parseAmount('9' * 30), 99999999999999);
  });

  test('typing groups the thousands and keeps the cursor at the end', () {
    const formatter = ThousandsFormatter();
    final out = formatter.formatEditUpdate(
      const TextEditingValue(text: '1234'),
      const TextEditingValue(text: '1234'),
    );
    expect(out.text, '1,234');
    expect(out.selection.baseOffset, 5);
  });

  test('typing in the middle keeps the cursor beside the new digit', () {
    const formatter = ThousandsFormatter();
    // "45,000" with the cursor after the 4; the person types 1.
    final out = formatter.formatEditUpdate(
      const TextEditingValue(text: '45,000', selection: TextSelection.collapsed(offset: 1)),
      const TextEditingValue(text: '415,000', selection: TextSelection.collapsed(offset: 2)),
    );
    expect(out.text, '415,000');
    expect(out.selection.baseOffset, 2, reason: 'just after the 1');
  });

  test('a new comma before the cursor moves the cursor with its digits', () {
    const formatter = ThousandsFormatter();
    // "1,234" with the cursor after the 2; the person types 9, giving 5 digits.
    final out = formatter.formatEditUpdate(
      const TextEditingValue(text: '1,234', selection: TextSelection.collapsed(offset: 3)),
      const TextEditingValue(text: '1,2934', selection: TextSelection.collapsed(offset: 4)),
    );
    expect(out.text, '12,934');
    expect(out.selection.baseOffset, 4, reason: 'still just after the 9, with 34 to its right');
  });

  test('deleting a digit in the middle keeps the cursor there', () {
    const formatter = ThousandsFormatter();
    // "1,284,000" with the cursor after the 8; backspace removes it.
    final out = formatter.formatEditUpdate(
      const TextEditingValue(text: '1,284,000', selection: TextSelection.collapsed(offset: 4)),
      const TextEditingValue(text: '1,24,000', selection: TextSelection.collapsed(offset: 3)),
    );
    expect(out.text, '124,000');
    expect(out.selection.baseOffset, 2, reason: 'between the 2 and the 4');
  });

  test('clearing the field leaves it empty', () {
    const formatter = ThousandsFormatter();
    final out = formatter.formatEditUpdate(
      const TextEditingValue(text: '5'),
      const TextEditingValue(),
    );
    expect(out.text, '');
  });
}
