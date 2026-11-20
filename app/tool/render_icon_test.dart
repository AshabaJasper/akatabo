// Renders the PROVISIONAL app icon from the design tokens: the wordmark's "A" in Bricolage
// Grotesque Bold, in the accent colour, on brand-deep green. It stands in until the owner
// supplies real icon artwork (a launch blocker in SHIP_GATE.md).
//
// Lives in tool/, so the normal `flutter test` run skips it. Run it with:
//   flutter test tool/render_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:akatabo/core/theme/tokens.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

/// Draws the "A". [glyphShare] is the letter's height as a share of the canvas: the full
/// icon uses more of it; the adaptive foreground keeps it inside Android's 66% safe zone.
Future<void> _render(
  String path, {
  required ui.Color? background,
  required ui.Color glyph,
  required double glyphShare,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (background != null) {
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, _size, _size), ui.Paint()..color = background);
  }
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'Bricolage Grotesque',
            fontSize: _size * glyphShare,
            fontWeight: ui.FontWeight.w700,
            height: 1,
          ),
        )
        ..pushStyle(ui.TextStyle(color: glyph, fontVariations: const [ui.FontVariation('opsz', 96)]))
        ..addText('A');
  final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: _size));
  final line = paragraph.computeLineMetrics().first;
  // Centre the cap height, not the line box, so the letter sits optically in the middle.
  final capTop = line.baseline - line.ascent * 0.72;
  final dy = (_size - (line.baseline - capTop)) / 2 - capTop;
  canvas.drawParagraph(paragraph, ui.Offset((_size - line.width) / 2 - line.left, dy));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render the provisional icon', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/fonts/BricolageGrotesque-Variable.ttf').readAsBytesSync();
      await (FontLoader(
        'Bricolage Grotesque',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();

      const t = akLightTokens;
      await _render(
        'assets/icon/icon.png',
        background: t.brandDeep,
        glyph: t.accent,
        glyphShare: 0.62,
      );
      await _render(
        'assets/icon/foreground.png',
        background: null,
        glyph: t.accent,
        glyphShare: 0.42,
      );
      await _render(
        'assets/icon/monochrome.png',
        background: null,
        glyph: const ui.Color(0xFFFFFFFF),
        glyphShare: 0.42,
      );
    });
  });
}
