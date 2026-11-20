import '../../smart/forecast/forecast_range.dart';

/// "Likely UGX 1,100,000 to UGX 1,400,000, most likely UGX 1,250,000", with [format] writing
/// each figure (full on the Forecast screen, short on the Home card).
String rangeInWords(ForecastRange range, String Function(int) format) =>
    'Likely ${format(range.low)} to ${format(range.high)}, most likely ${format(range.point)}';

/// What the range was worked out from, in plain words: the evidence the design asks every
/// Smart help result to carry.
String rangeEvidence(ForecastRange range) {
  const replays =
      'The range replays the everyday spending of those days $forecastSamples times; '
      '8 in 10 replays end inside it.';
  return switch (range.monthsUsed) {
    0 => replays,
    1 => '$replays It also allows for how far your forecast was out in 1 earlier month.',
    final k => '$replays It also allows for how far your forecasts were out in $k earlier months.',
  };
}
