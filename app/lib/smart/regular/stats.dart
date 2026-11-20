/// Small numeric helpers shared by the unusual and regular detectors. Each mirrors
/// ml/regular/payee.py operation for operation, so Dart and Python give the same doubles.
library;

/// The middle value; the mean of the two middle values for an even count.
double medianOf(Iterable<num> values) {
  final s = [for (final v in values) v.toDouble()]..sort();
  if (s.isEmpty) throw ArgumentError('median of nothing');
  final m = s.length ~/ 2;
  if (s.length.isOdd) return s[m];
  return (s[m - 1] + s[m]) / 2.0;
}

/// Adds left to right, as Python's hand-written plain_sum does. (Python's own sum() of
/// floats uses compensated summation, so it can differ in the last bit.)
double plainSum(Iterable<double> values) {
  var total = 0.0;
  for (final v in values) {
    total += v;
  }
  return total;
}

/// floor(x + 0.5). Dart's round() goes half away from zero and Python's half to even;
/// this is the same in both.
int roundHalfUp(double x) => (x + 0.5).floor();
