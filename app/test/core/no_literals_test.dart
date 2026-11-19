import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens and shared widgets read every colour, text size and corner from the theme.
/// This scan fails if one is typed in by hand.
void main() {
  final banned = <String, RegExp>{
    'a literal colour': RegExp(r'Color\(0x'),
    'a Material colour constant': RegExp(r'\bColors\.'),
    'a typed font size': RegExp(r'fontSize:\s*\d'),
    'a typed corner radius': RegExp(r'(Radius|BorderRadius)\.circular\(\s*\d'),
    'a typed TextStyle': RegExp(r'\bTextStyle\('),
  };

  final files = [
    for (final dir in ['lib/features', 'lib/widgets', 'lib/app'])
      if (Directory(dir).existsSync())
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart')),
  ];

  test('there are files to scan', () => expect(files, isNotEmpty));

  for (final file in files) {
    test('no hand-typed style values in ${file.path}', () {
      final lines = file.readAsLinesSync();
      final found = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        banned.forEach((what, pattern) {
          if (pattern.hasMatch(line)) {
            found.add('line ${i + 1}: $what: ${line.trim()}');
          }
        });
      }
      expect(found, isEmpty);
    });
  }
}
