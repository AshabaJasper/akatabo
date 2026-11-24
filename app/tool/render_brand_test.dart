// Writes the Akatabo brand files from the one geometry in lib/core/brand/akatabo_mark.dart:
// the SVG marks in design/brand/, a preview sheet of every variant, the launcher icon layers
// (assets/icon/, then `dart run flutter_launcher_icons`), notification and splash icons and
// splash colours (android/app/src/main/res/), iOS launch images, and store graphics.
//
// Lives in tool/, so the normal `flutter test` run skips it. Run it from app/ with:
//   flutter test tool/render_brand_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:akatabo/core/brand/akatabo_mark.dart';
import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';

const _brand = '../design/brand';

String _hex(ui.Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _rect(ui.RRect r, String fill, {double inflate = 0}) {
  final x = r.inflate(inflate);
  return '<rect x="${_n(x.left)}" y="${_n(x.top)}" width="${_n(x.width)}" '
      'height="${_n(x.height)}" rx="${_n(x.tlRadiusX)}" fill="$fill"/>';
}

String get _points => AkMarkGeometry.line.map((o) => '${_n(o.dx)},${_n(o.dy)}').join(' ');

String _line(String stroke) =>
    '<polyline points="$_points" fill="none" stroke="$stroke" '
    'stroke-width="${_n(AkMarkGeometry.lineWidth)}" stroke-linecap="round" stroke-linejoin="round"/>';

/// The mark's shapes in grid units, ready to drop into any SVG.
String _markShapes(AkMarkColours colours, String id) {
  switch (colours) {
    case AkMarkInColour(:final cover, :final page, :final line):
      return [
        _rect(AkMarkGeometry.backPage, _hex(page)),
        for (final r in AkMarkGeometry.rings) _rect(r, _hex(cover)),
        _rect(AkMarkGeometry.cover, _hex(cover)),
        _line(_hex(line)),
      ].join('\n    ');
    case AkMarkInOneColour(:final colour):
      final b = AkMarkGeometry.bounds.inflate(AkMarkGeometry.lineWidth);
      final fill = colour == const ui.Color(0x00000000) ? 'currentColor' : _hex(colour);
      return [
        '<mask id="$id-cut" maskUnits="userSpaceOnUse" x="${_n(b.left)}" y="${_n(b.top)}" '
            'width="${_n(b.width)}" height="${_n(b.height)}">',
        '  <rect x="${_n(b.left)}" y="${_n(b.top)}" width="${_n(b.width)}" '
            'height="${_n(b.height)}" fill="#FFFFFF"/>',
        '  ${_rect(AkMarkGeometry.cover, '#000000', inflate: AkMarkGeometry.monoGap)}',
        '</mask>',
        '<rect x="${_n(AkMarkGeometry.backPage.left)}" y="${_n(AkMarkGeometry.backPage.top)}" '
            'width="${_n(AkMarkGeometry.backPage.width)}" '
            'height="${_n(AkMarkGeometry.backPage.height)}" '
            'rx="${_n(AkMarkGeometry.backPage.tlRadiusX)}" fill="$fill" mask="url(#$id-cut)"/>',
        '<mask id="$id-line" maskUnits="userSpaceOnUse" x="${_n(b.left)}" y="${_n(b.top)}" '
            'width="${_n(b.width)}" height="${_n(b.height)}">',
        '  <rect x="${_n(b.left)}" y="${_n(b.top)}" width="${_n(b.width)}" '
            'height="${_n(b.height)}" fill="#FFFFFF"/>',
        '  ${_line('#000000')}',
        '</mask>',
        '<g fill="$fill" mask="url(#$id-line)">',
        for (final r in AkMarkGeometry.rings) '  ${_rect(r, fill)}',
        '  ${_rect(AkMarkGeometry.cover, fill)}',
        '</g>',
      ].join('\n    ');
  }
}

/// A file holding just the mark, its viewBox tight round the mark's bounds.
String _markSvg(AkMarkColours colours, String id) {
  final b = AkMarkGeometry.bounds;
  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="${_n(b.left)} ${_n(b.top)} ${_n(b.width)} ${_n(b.height)}" role="img" aria-labelledby="$id-title">
  <title id="$id-title">Akatabo</title>
  <g>
    ${_markShapes(colours, id)}
  </g>
</svg>
''';
}

/// A square tile with the mark centred at [share] of its side, on [background] with rounded
/// corners of [cornerShare] (0 for a full-bleed square).
String _tileSvg(
  AkMarkColours colours,
  ui.Color background,
  double share,
  double cornerShare,
  String id,
) {
  final b = AkMarkGeometry.bounds;
  const g = AkMarkGeometry.grid;
  final scale = g * share / b.longestSide;
  final tx = g / 2 - b.center.dx * scale;
  final ty = g / 2 - b.center.dy * scale;
  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(g)} ${_n(g)}" role="img" aria-labelledby="$id-title">
  <title id="$id-title">Akatabo</title>
  <rect width="${_n(g)}" height="${_n(g)}" rx="${_n(g * cornerShare)}" fill="${_hex(background)}"/>
  <g transform="translate(${_n(tx)} ${_n(ty)}) scale(${scale.toStringAsFixed(5)})">
    ${_markShapes(colours, id)}
  </g>
</svg>
''';
}

void _write(String path, String text) => File(path)
  ..createSync(recursive: true)
  ..writeAsStringSync(text);

Future<void> _png(String path, int width, int height, void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  const light = akLightTokens;
  const dark = akDarkTokens;
  final colour = AkMarkInColour(cover: light.brandDeep, page: dark.brandBright, line: light.accent);
  final reversed = AkMarkInColour(
    cover: light.ground,
    page: dark.brandBright,
    line: light.brandDeep,
  );
  final monoDark = AkMarkInOneColour(light.brandDeep);
  final monoLight = AkMarkInOneColour(light.ground);

  test('write the brand SVGs', () {
    _write('$_brand/akatabo-mark.svg', _markSvg(colour, 'akatabo-mark'));
    _write('$_brand/akatabo-mark-reversed.svg', _markSvg(reversed, 'akatabo-mark-reversed'));
    _write('$_brand/akatabo-mark-mono-dark.svg', _markSvg(monoDark, 'akatabo-mark-mono-dark'));
    _write('$_brand/akatabo-mark-mono-light.svg', _markSvg(monoLight, 'akatabo-mark-mono-light'));
    _write(
      '$_brand/akatabo-mark-mono.svg',
      _markSvg(const AkMarkInOneColour(ui.Color(0x00000000)), 'akatabo-mark-mono'),
    );
    _write(
      '$_brand/colours.json',
      '{\n'
          '  "ground": "${_hex(light.ground)}",\n'
          '  "groundDark": "${_hex(dark.ground)}",\n'
          '  "brandDeep": "${_hex(light.brandDeep)}",\n'
          '  "brandBright": "${_hex(dark.brandBright)}",\n'
          '  "accent": "${_hex(light.accent)}"\n'
          '}\n',
    );
    _write('$_brand/akatabo-icon.svg', _tileSvg(colour, light.ground, 0.62, 0.22, 'akatabo-icon'));
    _write(
      '$_brand/akatabo-icon-on-brand.svg',
      _tileSvg(reversed, light.brandDeep, 0.62, 0.22, 'akatabo-icon-on-brand'),
    );
  });

  testWidgets('render the preview sheet', (tester) async {
    await tester.runAsync(() async {
      const cell = 300.0;
      final tiles = <(ui.Color, AkMarkColours, double)>[
        (light.ground, colour, 0.62),
        (light.brandDeep, reversed, 0.62),
        (light.ground, monoDark, 0.62),
        (light.brandDeep, monoLight, 0.62),
      ];
      await _png('$_brand/preview.png', (cell * 4).toInt(), (cell + 140).toInt(), (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, cell * 4, cell + 140),
          ui.Paint()..color = light.surface,
        );
        for (var i = 0; i < tiles.length; i++) {
          final (bg, c, share) = tiles[i];
          final r = ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(i * cell + 20, 20, cell - 40, cell - 40),
            const ui.Radius.circular(56),
          );
          canvas
            ..drawRRect(r, ui.Paint()..color = bg)
            ..save()
            ..translate(r.left, r.top);
          AkMarkPainter(c, share: share).paint(canvas, ui.Size(r.width, r.height));
          canvas.restore();
        }
        // The colour mark at real launcher and notification sizes.
        var x = 20.0;
        for (final s in const [24.0, 32.0, 48.0, 72.0, 96.0]) {
          canvas
            ..save()
            ..translate(x, cell + 20);
          AkMarkPainter(colour).paint(canvas, ui.Size.square(s));
          canvas.restore();
          x += s + 24;
        }
        for (final s in const [24.0, 32.0, 48.0, 72.0]) {
          canvas
            ..save()
            ..translate(x, cell + 20);
          AkMarkPainter(monoDark).paint(canvas, ui.Size.square(s));
          canvas.restore();
          x += s + 24;
        }
      });
    });
  });

  testWidgets('write the app icon, splash, notification and store images', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/fonts/BricolageGrotesque-Variable.ttf').readAsBytesSync();
      await (FontLoader(
        'Bricolage Grotesque',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();

      Future<void> mark(
        String path,
        int size,
        AkMarkColours c,
        double share, {
        ui.Color? background,
      }) => _png(path, size, size, (canvas) {
        if (background != null) {
          canvas.drawRect(
            ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
            ui.Paint()..color = background,
          );
        }
        AkMarkPainter(c, share: share).paint(canvas, ui.Size.square(size.toDouble()));
      });

      const white = ui.Color(0xFFFFFFFF);
      // Launcher: full icon on paper (iOS and legacy Android), adaptive layers inside the
      // 66dp safe zone once the adaptive XML's 16% inset is applied.
      await mark('assets/icon/icon.png', 1024, colour, 0.62, background: light.ground);
      await mark('assets/icon/foreground.png', 1024, colour, 0.64);
      await mark('assets/icon/monochrome.png', 1024, const AkMarkInOneColour(white), 0.64);

      const res = 'android/app/src/main/res';
      // Android 12+ splash icon: 288dp, seen through a 192dp circle, so the mark takes half.
      await mark('$res/drawable-xxxhdpi/splash_icon.png', 960, colour, 0.5);
      await mark('$res/drawable-night-xxxhdpi/splash_icon.png', 960, reversed, 0.5);
      // Status-bar icon: white on transparent at each density.
      for (final (dpi, px) in const [
        ('mdpi', 24),
        ('hdpi', 36),
        ('xhdpi', 48),
        ('xxhdpi', 72),
        ('xxxhdpi', 96),
      ]) {
        await mark(
          '$res/drawable-$dpi/ic_stat_akatabo.png',
          px,
          const AkMarkInOneColour(white),
          0.9,
        );
      }
      _write('$res/values/brand_colors.xml', _colours(light.ground));
      _write('$res/values-night/brand_colors.xml', _colours(dark.ground));

      // iOS launch image and background, light and dark, like the Android splash. The
      // storyboard centres the image on the LaunchBackground colour.
      const xc = 'ios/Runner/Assets.xcassets';
      for (final (suffix, px) in const [('', 168), ('@2x', 336), ('@3x', 504)]) {
        await mark('$xc/LaunchImage.imageset/LaunchImage$suffix.png', px, colour, 0.9);
        await mark('$xc/LaunchImage.imageset/LaunchImageDark$suffix.png', px, reversed, 0.9);
      }
      _write('$xc/LaunchImage.imageset/Contents.json', _launchImageJson());
      _write(
        '$xc/LaunchBackground.colorset/Contents.json',
        _launchColourJson(light.ground, dark.ground),
      );

      // Store graphics: Play icon (Play applies its own mask), feature graphic, README banners.
      await mark('$_brand/store/icon-512.png', 512, colour, 0.62, background: light.ground);
      await _png('$_brand/store/feature-graphic.png', 1024, 500, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 1024, 500),
          ui.Paint()..color = light.brandDeep,
        );
        _lockup(canvas, const ui.Rect.fromLTWH(0, 0, 1024, 500), reversed, light.ground, 112);
      });
      for (final (name, bg, c, ink) in [
        ('banner-light', light.ground, colour, light.brandDeep),
        ('banner-dark', light.brandDeep, reversed, light.ground),
      ]) {
        await _png('$_brand/$name.png', 1280, 320, (canvas) {
          canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1280, 320), ui.Paint()..color = bg);
          _lockup(canvas, const ui.Rect.fromLTWH(0, 0, 1280, 320), c, ink, 96);
        });
      }
    });
  });

  testWidgets('render the lockup previews', (tester) async {
    await tester.runAsync(() async {
      final files = [
        'akatabo-lockup.svg',
        'akatabo-lockup-on-brand.svg',
        'akatabo-lockup-stacked.svg',
        'akatabo-lockup-stacked-on-brand.svg',
      ];
      if (!File('$_brand/${files.first}').existsSync()) return; // run brand_lockups.py first
      const w = 1200.0;
      const rowH = 260.0;
      await _png('$_brand/preview-lockups.png', w.toInt(), (rowH * 2 + 60).toInt(), (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, w, rowH * 2 + 60),
          ui.Paint()..color = light.surface,
        );
        final slots = [
          const ui.Rect.fromLTWH(20, 20, 560, rowH - 40),
          const ui.Rect.fromLTWH(620, 20, 560, rowH - 40),
          const ui.Rect.fromLTWH(20, rowH, 560, rowH + 20),
          const ui.Rect.fromLTWH(620, rowH, 560, rowH + 20),
        ];
        for (var i = 0; i < files.length; i++) {
          _drawSvg(canvas, File('$_brand/${files[i]}').readAsStringSync(), slots[i]);
        }
      });
    });
  });
}

/// Draws the small SVG subset the brand files use (rect, polyline, path; translate and
/// scale transforms; no masks) into [box], keeping its aspect ratio.
void _drawSvg(ui.Canvas canvas, String svg, ui.Rect box) {
  double attr(String el, String name) =>
      double.parse(RegExp('$name="([-0-9.]+)"').firstMatch(el)!.group(1)!);
  String? sattr(String el, String name) => RegExp('$name="([^"]*)"').firstMatch(el)?.group(1);
  ui.Color colour(String hex) => ui.Color(int.parse('FF${hex.substring(1)}', radix: 16));
  final vb = sattr(svg, 'viewBox')!.split(' ').map(double.parse).toList();
  final scale = [box.width / vb[2], box.height / vb[3]].reduce((a, b) => a < b ? a : b);
  canvas
    ..save()
    ..translate(box.center.dx - vb[2] * scale / 2, box.center.dy - vb[3] * scale / 2)
    ..scale(scale)
    ..translate(-vb[0], -vb[1]);
  void applyTransform(String? t) {
    if (t == null) return;
    for (final m in RegExp(r'(translate|scale)\(([^)]*)\)').allMatches(t)) {
      final v = m.group(2)!.trim().split(RegExp(r'[ ,]+')).map(double.parse).toList();
      if (m.group(1) == 'translate') {
        canvas.translate(v[0], v.length > 1 ? v[1] : 0);
      } else {
        canvas.scale(v[0], v.length > 1 ? v[1] : v[0]);
      }
    }
  }

  final tokens = RegExp(r'<(/?)(g|rect|polyline|path)\b([^>]*?)(/?)>').allMatches(svg);
  for (final m in tokens) {
    final closing = m.group(1) == '/';
    final tag = m.group(2)!;
    final el = m.group(3)!;
    if (tag == 'g') {
      if (closing) {
        canvas.restore();
      } else {
        canvas.save();
        applyTransform(sattr(el, 'transform'));
      }
      continue;
    }
    if (tag == 'rect') {
      final x = sattr(el, 'x') == null ? 0.0 : attr(el, 'x');
      final y = sattr(el, 'y') == null ? 0.0 : attr(el, 'y');
      final rx = sattr(el, 'rx') == null ? 0.0 : attr(el, 'rx');
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(x, y, attr(el, 'width'), attr(el, 'height')),
          ui.Radius.circular(rx),
        ),
        ui.Paint()..color = colour(sattr(el, 'fill')!),
      );
    } else if (tag == 'polyline') {
      final pts = sattr(el, 'points')!.split(' ').map((p) {
        final xy = p.split(',').map(double.parse).toList();
        return ui.Offset(xy[0], xy[1]);
      }).toList();
      canvas.drawPath(
        ui.Path()..addPolygon(pts, false),
        ui.Paint()
          ..color = colour(sattr(el, 'stroke')!)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = attr(el, 'stroke-width')
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round,
      );
    } else if (tag == 'path') {
      final path = ui.Path();
      writeSvgPathDataToPath(sattr(el, 'd'), _Writer(path));
      canvas.save();
      applyTransform(sattr(el, 'transform'));
      canvas
        ..drawPath(path, ui.Paint()..color = colour(sattr(el, 'fill')!))
        ..restore();
    }
  }
  canvas.restore();
}

class _Writer extends PathProxy {
  _Writer(this.path);
  final ui.Path path;
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

String _colours(ui.Color ground) =>
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- Written by tool/render_brand_test.dart from design/tokens.json; do not edit. -->\n'
    '<resources>\n'
    '    <color name="splash_background">${_hex(ground)}</color>\n'
    '</resources>\n';

/// The mark beside the wordmark (live Bricolage text), centred in [box].
void _lockup(ui.Canvas canvas, ui.Rect box, AkMarkColours c, ui.Color ink, double fontSize) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'Bricolage Grotesque',
            fontSize: fontSize,
            fontWeight: ui.FontWeight.w700,
            height: 1,
          ),
        )
        ..pushStyle(ui.TextStyle(color: ink, fontVariations: const [ui.FontVariation('opsz', 96)]))
        ..addText('Akatabo');
  final p = builder.build()..layout(const ui.ParagraphConstraints(width: 4000));
  final line = p.computeLineMetrics().first;
  final markSide = fontSize * 1.25;
  final gap = fontSize * 0.3;
  final left = box.center.dx - (markSide + gap + line.width) / 2;
  canvas
    ..save()
    ..translate(left, box.center.dy - markSide / 2);
  AkMarkPainter(c).paint(canvas, ui.Size.square(markSide));
  canvas.restore();
  // Centre the cap height (about 0.66 em) on the mark.
  final capTop = line.baseline - fontSize * 0.66;
  canvas.drawParagraph(
    p,
    ui.Offset(left + markSide + gap, box.center.dy - fontSize * 0.33 - capTop),
  );
}

/// The launch image set: each scale once for any appearance and once for dark.
String _launchImageJson() {
  final images = <String>[];
  for (final scale in const ['1x', '2x', '3x']) {
    final suffix = scale == '1x' ? '' : '@$scale';
    images
      ..add(
        '    {\n      "idiom" : "universal",\n      "filename" : "LaunchImage$suffix.png",\n'
        '      "scale" : "$scale"\n    }',
      )
      ..add(
        '    {\n      "appearances" : [\n        {\n          "appearance" : "luminosity",\n'
        '          "value" : "dark"\n        }\n      ],\n      "idiom" : "universal",\n'
        '      "filename" : "LaunchImageDark$suffix.png",\n      "scale" : "$scale"\n    }',
      );
  }
  return '{\n  "images" : [\n${images.join(',\n')}\n  ],\n'
      '  "info" : {\n    "version" : 1,\n    "author" : "xcode"\n  }\n}\n';
}

/// The launch background colour set, the screen ground in light and dark.
String _launchColourJson(ui.Color light, ui.Color dark) {
  String entry(ui.Color c, {bool isDark = false}) {
    String ch(double v) => '0x${(v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final appearance = isDark
        ? '      "appearances" : [\n        {\n          "appearance" : "luminosity",\n'
              '          "value" : "dark"\n        }\n      ],\n'
        : '';
    return '    {\n$appearance      "color" : {\n        "color-space" : "srgb",\n'
        '        "components" : {\n          "alpha" : "1.000",\n'
        '          "blue" : "${ch(c.b)}",\n          "green" : "${ch(c.g)}",\n'
        '          "red" : "${ch(c.r)}"\n        }\n      },\n      "idiom" : "universal"\n    }';
  }

  return '{\n  "colors" : [\n${entry(light)},\n${entry(dark, isDark: true)}\n  ],\n'
      '  "info" : {\n    "version" : 1,\n    "author" : "xcode"\n  }\n}\n';
}
