import 'package:akatabo/core/format/money.dart';
import 'package:akatabo/smart/text_normaliser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amounts have comma separators and UGX goes before the number', () {
    expect(formatAmount(1284000), '1,284,000');
    expect(formatAmount(0), '0');
    expect(formatUgx(1284000), 'UGX 1,284,000');
  });

  test('direction is written as a sign with a space', () {
    expect(formatSigned(45000, moneyIn: false), '- 45,000');
    expect(formatSigned(250000, moneyIn: true), '+ 250,000');
  });

  test('short form for charts and tiles', () {
    expect(formatShort(1830000), '1.83M');
    expect(formatShort(1650000), '1.65M');
    expect(formatShort(2000000), '2M');
    expect(formatShort(1500000), '1.5M');
    expect(formatShort(298000), '298k');
    expect(formatShort(999600), '1M');
    expect(formatShort(950), '950');
  });

  test('percentages are whole unless under 10, then one decimal', () {
    expect(formatPercent(32.4), '32%');
    expect(formatPercent(8.46), '8.5%');
    expect(formatPercent(4), '4.0%');
    expect(formatPercent(9.96), '10%');
    expect(formatPercent(-12.2), '12%');
  });

  test('a share of nothing is zero, not an error', () {
    expect(shareOf(5, 0), 0);
    expect(shareOf(412000, 1284000), closeTo(32.09, 0.01));
  });

  test('payee keys ignore case, punctuation and spacing', () {
    expect(payeeKeyOf('Groceries, Nakasero  market'), 'groceries nakasero market');
    expect(payeeKeyOf('  YAKA electricity!'), 'yaka electricity');
    expect(payeeKeyOf(''), '');
  });
}
