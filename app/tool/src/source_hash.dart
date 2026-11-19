import 'dart:convert';

/// FNV-1a 64-bit hash of [text] (line endings normalised), as 16 hex digits.
///
/// Generated files carry the hash of the design file they came from, so a test can tell
/// when `design/tokens.json` or the icon table changed and the generated Dart is stale.
String sourceHash(String text) {
  final bytes = utf8.encode(text.replaceAll('\r\n', '\n'));
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in bytes) {
    hash = ((hash ^ BigInt.from(b)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// `brand-deep` -> `brandDeep`, `space-0h` -> `space0h`, `heat-0` -> `heat0`.
String camel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();
}
