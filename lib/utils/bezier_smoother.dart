import 'dart:ui';
import '../models/drawing_point.dart';

class BezierSmoother {
  /// Converts a sequence of normalized points to a smooth Path on [canvasSize].
  static Path pointsToPath(List<DrawingPoint> points, Size canvasSize) {
    final Path path = Path();
    if (points.isEmpty) return path;

    final first = points[0].toOffset(canvasSize);

    if (points.length == 1) {
      path.addOval(Rect.fromCircle(center: first, radius: 0.5));
      return path;
    }

    path.moveTo(first.dx, first.dy);

    if (points.length == 2) {
      final second = points[1].toOffset(canvasSize);
      path.lineTo(second.dx, second.dy);
      return path;
    }

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1].toOffset(canvasSize);
      final p2 = points[i].toOffset(canvasSize);
      final midX = (p1.dx + p2.dx) / 2.0;
      final midY = (p1.dy + p2.dy) / 2.0;
      path.quadraticBezierTo(p1.dx, p1.dy, midX, midY);
    }

    final last = points.last.toOffset(canvasSize);
    path.lineTo(last.dx, last.dy);
    return path;
  }
}
