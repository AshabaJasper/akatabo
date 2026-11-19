import 'dart:io';

import 'package:akatabo/core/icons/icon_registry.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_icons.dart' as icons;
import '../../tool/src/source_hash.dart';

String _hashIn(String path) =>
    RegExp(r'source-hash: (\w+)').firstMatch(File(path).readAsStringSync())!.group(1)!;

void main() {
  group('generated files match the design files', () {
    test('tokens.g.dart is up to date with design/tokens.json', () {
      final source = File('../design/tokens.json').readAsStringSync();
      expect(
        _hashIn('lib/core/theme/tokens.g.dart'),
        sourceHash(source),
        reason: 'design/tokens.json changed: run `dart run tool/gen_tokens.dart`',
      );
    });

    test('icon_registry.g.dart is up to date with the icon table', () {
      final source = File('../design/DESIGN_SYSTEM.md').readAsStringSync();
      expect(
        _hashIn('lib/core/icons/icon_registry.g.dart'),
        sourceHash(icons.iconSection(source)),
        reason: 'The icon table changed: run `dart run tool/gen_icons.dart`',
      );
    });
  });

  test('every icon in the table is in the registry, in table order, and nothing else', () {
    final rows = icons.parseIcons(File('../design/DESIGN_SYSTEM.md').readAsStringSync());
    expect(AkIcons.values.map((i) => i.key).toList(), rows.map((r) => r.name).toList());
    for (final row in rows) {
      expect(AkIcons.fromKey(row.name).shapes, hasLength(row.shapes.length), reason: row.name);
    }
  });

  test('the icon table parses the same with Windows line endings', () {
    final src = File('../design/DESIGN_SYSTEM.md').readAsStringSync().replaceAll('\r\n', '\n');
    final crlf = src.replaceAll('\n', '\r\n');
    expect(icons.parseIcons(crlf).length, icons.parseIcons(src).length);
    expect(sourceHash(icons.iconSection(crlf)), sourceHash(icons.iconSection(src)));
  });

  test('an unknown icon key falls back to dots', () {
    expect(AkIcons.fromKey('no-such-icon'), AkIcons.dots);
  });
}
