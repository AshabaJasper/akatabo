import 'package:material_ui/material_ui.dart';
import 'package:path_parsing/path_parsing.dart';

import '../theme/tokens.g.dart' show AkSize;
import 'ak_icon_shape.dart';
import 'icon_registry.g.dart';

export 'icon_registry.g.dart';

/// Draws one icon from the design system's table: shapes on a 24 by 24 grid, a round
/// stroke of [strokeWidth] grid units, in [color] (the icon theme colour by default).
///
/// The icon is painted synchronously, so it is there on the first frame and in goldens.
class AkIcon extends StatelessWidget {
  const AkIcon(
    this.icon, {
    super.key,
    this.size = AkSize.icon,
    this.color,
    this.strokeWidth = 2,
    this.semanticLabel,
  });

  final AkIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// Read by screen readers. Leave null for an icon beside text that says the same thing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: Size.square(size),
      painter: AkIconPainter(
        icon,
        color: color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color!,
        strokeWidth: strokeWidth,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: semanticLabel, image: true, child: paint);
  }
}

class AkIconPainter extends CustomPainter {
  AkIconPainter(this.icon, {required this.color, this.strokeWidth = 2});

  final AkIcons icon;
  final Color color;
  final double strokeWidth;

  static final Map<AkIcons, Path> _cache = {};

  /// The icon's outline on the 24 grid, parsed once per icon.
  static Path pathFor(AkIcons icon) => _cache.putIfAbsent(icon, () {
    final path = Path();
    for (final shape in icon.shapes) {
      switch (shape) {
        case AkIconPath(:final d):
          writeSvgPathDataToPath(d, _PathWriter(path));
        case AkIconCircle(:final cx, :final cy, :final r):
          path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
        case AkIconRect(:final x, :final y, :final width, :final height, :final rx):
          path.addRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height), Radius.circular(rx)),
          );
      }
    }
    return path;
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..scale(scale);
    canvas.drawPath(
      pathFor(icon),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AkIconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

class _PathWriter extends PathProxy {
  _PathWriter(this.path);
  final Path path;

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
