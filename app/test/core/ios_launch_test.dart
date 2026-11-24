import 'dart:convert';
import 'dart:io';

import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The iOS launch screen has a dark version, like the Android splash, so a phone in dark
/// mode does not flash a paper screen before the dark app. Written by
/// `tool/render_brand_test.dart`; this guards the files that tool writes.
void main() {
  const xc = 'ios/Runner/Assets.xcassets';

  test('the storyboard takes its background from the LaunchBackground colour set', () {
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, contains('<color key="backgroundColor" name="LaunchBackground"/>'));
  });

  test('the colour set is the screen ground in light and dark', () {
    final json = jsonDecode(
      File('$xc/LaunchBackground.colorset/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final colours = (json['colors'] as List).cast<Map<String, dynamic>>();
    Color read(Map<String, dynamic> entry) {
      final c = (entry['color'] as Map<String, dynamic>)['components'] as Map<String, dynamic>;
      int ch(String k) => int.parse((c[k] as String).substring(2), radix: 16);
      return Color.fromARGB(255, ch('red'), ch('green'), ch('blue'));
    }

    final dark = colours.singleWhere((e) => e.containsKey('appearances'));
    final any = colours.singleWhere((e) => !e.containsKey('appearances'));
    expect(read(any), akLightTokens.ground);
    expect(read(dark), akDarkTokens.ground);
  });

  test('every launch image scale has a dark twin on disk', () {
    final json = jsonDecode(
      File('$xc/LaunchImage.imageset/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final images = (json['images'] as List).cast<Map<String, dynamic>>();
    final darkScales = images
        .where((e) => e.containsKey('appearances'))
        .map((e) => e['scale'])
        .toSet();
    expect(darkScales, {'1x', '2x', '3x'});
    for (final image in images) {
      expect(File('$xc/LaunchImage.imageset/${image['filename']}').existsSync(), isTrue);
    }
  });
}
