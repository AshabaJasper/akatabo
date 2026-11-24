import 'package:material_ui/material_ui.dart';

/// The Akatabo mark: a spiral notebook ("akatabo" is "a small book") with a rising line on
/// its cover. Chosen by the owner on 24 November 2026 from ChatGPT concept 2 and redrawn
/// here as plain geometry, so the app, the launcher icons and the SVG files in
/// `design/brand/` all come from the same numbers (`tool/render_brand_test.dart`).
///
/// Everything sits on a 1024 by 1024 grid, centred. Colours are passed in, so callers use
/// design tokens.
abstract final class AkMarkGeometry {
  static const double grid = 1024;

  static const double _dx = 4;
  static const double _dy = 2;

  /// The cover, in the main colour.
  static final RRect cover = RRect.fromRectAndRadius(
    const Rect.fromLTWH(300 + _dx, 200 + _dy, 440, 580),
    const Radius.circular(72),
  );

  /// The page block behind the cover, showing on the right and at the bottom.
  static final RRect backPage = cover.shift(const Offset(40, 40));

  /// The spiral rings on the left edge.
  static final List<RRect> rings = [
    for (final y in const [278.0, 398.0, 518.0, 638.0])
      RRect.fromRectAndRadius(
        Rect.fromLTWH(236 + _dx, y + _dy, 104, 44),
        const Radius.circular(22),
      ),
  ];

  /// The rising line on the cover, drawn as a round-capped stroke of [lineWidth].
  static const List<Offset> line = [
    Offset(386 + _dx, 616 + _dy),
    Offset(494 + _dx, 500 + _dy),
    Offset(574 + _dx, 568 + _dy),
    Offset(690 + _dx, 400 + _dy),
  ];
  static const double lineWidth = 66;

  /// The clear gap kept around the cover in the one-colour version, so the cover and the
  /// page block stay two shapes.
  static const double monoGap = 24;

  /// The mark's outer bounds on the grid (rings, cover and page block).
  static Rect get bounds =>
      Rect.fromLTRB(rings.first.left, cover.top, backPage.right, backPage.bottom);
}

/// How the mark is coloured.
sealed class AkMarkColours {
  const AkMarkColours();
}

/// Cover and rings in [cover], page block in [page], line in [line].
final class AkMarkInColour extends AkMarkColours {
  const AkMarkInColour({required this.cover, required this.page, required this.line});
  final Color cover;
  final Color page;
  final Color line;

  @override
  bool operator ==(Object other) =>
      other is AkMarkInColour && other.cover == cover && other.page == page && other.line == line;

  @override
  int get hashCode => Object.hash(cover, page, line);
}

/// One colour; the line and the gap round the cover are cut out (themed icons,
/// notification icons, single-colour print).
final class AkMarkInOneColour extends AkMarkColours {
  const AkMarkInOneColour(this.colour);
  final Color colour;

  @override
  bool operator ==(Object other) => other is AkMarkInOneColour && other.colour == colour;

  @override
  int get hashCode => colour.hashCode;
}

/// Paints the mark into a square: the mark's 1024 grid is scaled to the shorter side.
/// [share] is how much of that square the mark's bounds may take (1 fills it edge to edge),
/// so the same painter serves a small logo and an adaptive-icon safe zone.
class AkMarkPainter extends CustomPainter {
  const AkMarkPainter(this.colours, {this.share = 1});

  final AkMarkColours colours;
  final double share;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final b = AkMarkGeometry.bounds;
    final scale = side * share / b.longestSide;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-b.center.dx, -b.center.dy);
    switch (colours) {
      case AkMarkInColour(:final cover, :final page, :final line):
        _paintColour(canvas, cover, page, line);
      case AkMarkInOneColour(:final colour):
        _paintOneColour(canvas, colour);
    }
    canvas.restore();
  }

  static Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  static Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = AkMarkGeometry.lineWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static Path get _linePath => Path()..addPolygon(AkMarkGeometry.line, false);

  void _paintColour(Canvas canvas, Color cover, Color page, Color line) {
    canvas.drawRRect(AkMarkGeometry.backPage, _fill(page));
    for (final r in AkMarkGeometry.rings) {
      canvas.drawRRect(r, _fill(cover));
    }
    canvas
      ..drawRRect(AkMarkGeometry.cover, _fill(cover))
      ..drawPath(_linePath, _stroke(line));
  }

  void _paintOneColour(Canvas canvas, Color colour) {
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas
      ..saveLayer(null, Paint())
      ..drawRRect(AkMarkGeometry.backPage, _fill(colour))
      ..drawRRect(AkMarkGeometry.cover.inflate(AkMarkGeometry.monoGap), clear);
    for (final r in AkMarkGeometry.rings) {
      canvas.drawRRect(r, _fill(colour));
    }
    canvas
      ..drawRRect(AkMarkGeometry.cover, _fill(colour))
      ..drawPath(_linePath, _stroke(colour)..blendMode = BlendMode.clear)
      ..restore();
  }

  @override
  bool shouldRepaint(AkMarkPainter old) => old.colours != colours || old.share != share;
}
