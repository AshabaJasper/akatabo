import '../../domain/currency.dart';
import 'setting_keys.dart';

/// The exchange rates the person has typed, remembered so the next foreign entry starts with
/// them. Each one is a row of the Settings table, `rate.<ISO code>`, holding the rate in micros
/// (see `domain/currency.dart`). Settings rows travel through backup and restore already, so
/// these need no table of their own.
const _prefix = 'rate.';

/// The setting that holds the rate for [code], such as "USD".
StringSetting rateSetting(String code) => StringSetting('$_prefix$code', '');

/// Every remembered rate in [settings], as code to micros, sorted by code. A value that is not
/// a rate is left out rather than shown wrong.
Map<String, int> rememberedRates(Map<String, String> settings) {
  final rates = <String, int>{};
  for (final e in settings.entries) {
    if (!e.key.startsWith(_prefix)) continue;
    final code = e.key.substring(_prefix.length);
    if (!isForeignCode(code)) continue;
    final micros = int.tryParse(e.value);
    if (micros == null || micros <= 0) continue;
    rates[code] = micros;
  }
  return Map.fromEntries(rates.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}
