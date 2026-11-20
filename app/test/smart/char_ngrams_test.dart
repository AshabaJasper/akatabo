import 'package:akatabo/smart/category/char_ngrams.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expected lists are scikit-learn's own output (TfidfVectorizer(analyzer="char_wb",
/// ngram_range=(2, 4)).build_analyzer()), also checked in ml/category/tests.
void main() {
  test('a short word gives itself once at each length it is too short for', () {
    expect(charWbNgrams('a'), [' a', 'a ', ' a ']);
    expect(charWbNgrams('ab'), [' a', 'ab', 'b ', ' ab', 'ab ', ' ab ']);
  });

  test('every word is padded and n-grams stay inside it', () {
    expect(charWbNgrams('x y'), [' x', 'x ', ' x ', ' y', 'y ', ' y ']);
    expect(charWbNgrams('abc'), [' a', 'ab', 'bc', 'c ', ' ab', 'abc', 'bc ', ' abc', 'abc ']);
  });

  test('upper case and runs of spaces do not change the result', () {
    expect(charWbNgrams('Boda   TO work'), charWbNgrams('boda to work'));
    expect(charWbNgrams(''), isEmpty);
    expect(charWbNgrams('   '), isEmpty);
  });
}
