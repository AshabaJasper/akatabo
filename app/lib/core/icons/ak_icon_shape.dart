/// One shape of an icon on the 24 by 24 grid: an SVG path, a circle or a rounded rectangle.
sealed class AkIconShape {
  const AkIconShape();

  const factory AkIconShape.path(String d) = AkIconPath;
  const factory AkIconShape.circle(double cx, double cy, double r) = AkIconCircle;
  const factory AkIconShape.rect(double x, double y, double width, double height, double rx) =
      AkIconRect;
}

final class AkIconPath extends AkIconShape {
  const AkIconPath(this.d);
  final String d;
}

final class AkIconCircle extends AkIconShape {
  const AkIconCircle(this.cx, this.cy, this.r);
  final double cx;
  final double cy;
  final double r;
}

final class AkIconRect extends AkIconShape {
  const AkIconRect(this.x, this.y, this.width, this.height, this.rx);
  final double x;
  final double y;
  final double width;
  final double height;
  final double rx;
}
