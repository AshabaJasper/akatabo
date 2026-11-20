/// scikit-learn's `char_wb` analyser, written out so the phone builds the same features the
/// model was trained on: lower case, runs of white space collapsed, each word padded with one
/// space on both sides, then every n-gram of length [min] to [max] inside the padded word.
/// A word shorter than n gives itself once and stops there, as sklearn does.
///
/// Mirrors `char_wb_ngrams` in ml/category/features.py. Works on code points (runes), like
/// Python strings, so a character outside the basic plane counts once. No Flutter imports.
library;

final _whiteSpaces = RegExp(r'\s\s+');
final _anyWhiteSpace = RegExp(r'\s+');

List<String> charWbNgrams(String text, {int min = 2, int max = 4}) {
  final collapsed = text.toLowerCase().replaceAll(_whiteSpaces, ' ');
  final out = <String>[];
  for (final word in collapsed.split(_anyWhiteSpace)) {
    if (word.isEmpty) continue;
    final w = [32, ...word.runes, 32];
    final len = w.length;
    for (var n = min; n <= max; n++) {
      var offset = 0;
      out.add(String.fromCharCodes(w.sublist(offset, _end(offset + n, len))));
      while (offset + n < len) {
        offset++;
        out.add(String.fromCharCodes(w.sublist(offset, offset + n)));
      }
      // The word is shorter than n: it was counted once, whole.
      if (offset == 0) break;
    }
  }
  return out;
}

int _end(int want, int len) => want < len ? want : len;
