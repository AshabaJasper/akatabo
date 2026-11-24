import 'package:akatabo/data/settings/remembered_rates.dart';
import 'package:akatabo/domain/currency.dart';
import 'package:akatabo/features/add/currency_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 3,720 shillings per dollar, in micros.
const _usd = 3720000000;

void main() {
  group('converting to whole shillings', () {
    test('an exact conversion has no rounding', () {
      expect(ugxFor(foreignMinor: 10000, rateMicros: _usd), 372000);
    });

    test('a half shilling rounds up to the next whole one', () {
      // 0.50 of a unit at 1 shilling a unit is exactly half a shilling.
      expect(ugxFor(foreignMinor: 50, rateMicros: 1000000), 1);
    });

    test('below a half rounds down, above a half rounds up', () {
      // 0.49 of a unit at 1 shilling, and 0.51 of a unit.
      expect(ugxFor(foreignMinor: 49, rateMicros: 1000000), 0);
      expect(ugxFor(foreignMinor: 51, rateMicros: 1000000), 1);
    });

    test('two and a half rounds to three, not to two (half up, not to even)', () {
      expect(ugxFor(foreignMinor: 250, rateMicros: 1000000), 3);
      expect(ugxFor(foreignMinor: 350, rateMicros: 1000000), 4);
    });

    test('a fractional rate is exact before rounding', () {
      // 100 dollars at 3,720.5 shillings: 372,050 exactly.
      expect(ugxFor(foreignMinor: 10000, rateMicros: 3720500000), 372050);
    });

    test('a reversal rounds away from zero, so it matches its original', () {
      expect(ugxFor(foreignMinor: -50, rateMicros: 1000000), -1);
      expect(ugxFor(foreignMinor: -10000, rateMicros: _usd), -372000);
    });

    test('a large amount does not overflow', () {
      // A million dollars at 3,720: 3.72 billion shillings.
      expect(ugxFor(foreignMinor: 1000000 * 100, rateMicros: _usd), 3720000000);
      // The largest amount and rate that can be typed still come out exact.
      expect(
        ugxFor(foreignMinor: 10000000000 * 100, rateMicros: 10000000 * 1000000),
        10000000000 * 10000000,
      );
    });

    test('typed amounts and rates beyond any real figure are refused', () {
      expect(parseForeignMinor('10000000001'), isNull);
      expect(parseRateMicros('10000001'), isNull);
    });
  });

  group('reading what the person typed', () {
    test('a rate with commas, decimals, or neither', () {
      expect(parseRateMicros('3,720'), _usd);
      expect(parseRateMicros('3720'), _usd);
      expect(parseRateMicros('3720.5'), 3720500000);
      expect(parseRateMicros(' 3 720 '), _usd);
    });

    test('a rate that is zero, empty, negative or too precise is refused', () {
      expect(parseRateMicros('0'), isNull);
      expect(parseRateMicros(''), isNull);
      expect(parseRateMicros('-3720'), isNull);
      expect(parseRateMicros('3720.1234567'), isNull);
      expect(parseRateMicros('abc'), isNull);
    });

    test('an amount keeps its cents, and a whole amount is hundredths of a unit', () {
      expect(parseForeignMinor('100'), 10000);
      expect(parseForeignMinor('100.5'), 10050);
      expect(parseForeignMinor('1,000.50'), 100050);
      expect(parseForeignMinor('0'), isNull);
      expect(parseForeignMinor('12.345'), isNull);
    });

    test('a code is three capital letters and is never UGX', () {
      expect(isForeignCode('USD'), isTrue);
      expect(isForeignCode('JPY'), isTrue);
      expect(isForeignCode('UGX'), isFalse);
      expect(isForeignCode('us'), isFalse);
      expect(isForeignCode('USDT'), isFalse);
    });
  });

  group('showing amounts', () {
    test('a rate has no trailing zeros', () {
      expect(formatRate(_usd), '3,720');
      expect(formatRate(3720500000), '3,720.5');
    });

    test('a foreign amount shows cents only when it has them', () {
      expect(formatForeign('USD', 10000), 'USD 100');
      expect(formatForeign('USD', 10050), 'USD 100.50');
      expect(foreignFieldText(100050), '1,000.50');
    });

    test('the detail line reads "USD 100 at 3,720"', () {
      expect(foreignSummary('USD', 10000, _usd), 'USD 100 at 3,720');
    });

    test('the spreadsheet cells are plain numbers, never grouped', () {
      expect(plainForeign(100050), '1000.50');
      expect(plainForeign(10000), '100');
      expect(plainRate(3720500000), '3720.5');
      expect(plainRate(_usd), '3720');
    });
  });

  group('a rate opened and saved again', () {
    test('keeps all six decimals, so it comes back unchanged', () {
      expect(formatRate(3720123456), '3,720.123456');
      expect(parseRateMicros(formatRate(3720123456)), 3720123456);
    });
  });

  group('typing an amount or a rate', () {
    TextEditingValue type(TextInputFormatter f, String old, String next) => f.formatEditUpdate(
      TextEditingValue(
        text: old,
        selection: TextSelection.collapsed(offset: old.length),
      ),
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );

    test('a comma typed on a decimal-comma phone is the decimal point', () {
      const f = ForeignAmountFormatter();
      final afterComma = type(f, '100', '100,').text;
      expect(afterComma, '100.');
      expect(type(f, afterComma, '${afterComma}5').text, '100.5');
      expect(parseForeignMinor(type(f, afterComma, '${afterComma}5').text), 10050);
    });

    test('once there is a full stop, a typed comma is ignored', () {
      const f = ForeignAmountFormatter();
      expect(type(f, '100.5', '100.5,').text, '100.5');
    });

    test('thousands commas are written by the field, so long amounts still group', () {
      const f = ForeignAmountFormatter();
      expect(type(f, '1,000', '1,0000').text, '10,000');
    });

    test('an amount keeps two decimals; a rate keeps six', () {
      expect(type(const ForeignAmountFormatter(), '1.23', '1.234').text, '1.23');
      const rate = ForeignAmountFormatter(decimals: rateDecimals);
      expect(type(rate, '3720.12345', '3720.123456').text, '3,720.123456');
    });
  });

  group('remembered rates', () {
    test('only real rates for three-letter codes are kept, sorted by code', () {
      final rates = rememberedRates({
        'rate.USD': '$_usd',
        'rate.KES': '23000000',
        'rate.EUR': '',
        'rate.gbp': '1',
        'rate.UGX': '1000000',
        'appearance.theme': 'dark',
      });
      expect(rates.keys.toList(), ['KES', 'USD']);
      expect(rates['USD'], _usd);
    });

    test('a rate setting is named for its code', () {
      expect(rateSetting('USD').name, 'rate.USD');
    });
  });
}
