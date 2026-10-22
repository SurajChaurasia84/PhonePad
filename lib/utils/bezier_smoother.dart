import 'dart:ui';
import '../models/drawing_point.dart';

class BezierSmoother {
  /// Converts a sequence of normalized points to a smooth continuous curve on [canvasSize].
  static Path pointsToPath(List<DrawingPoint> points, Size canvasSize) {
    final Path path = Path();
    if (points.isEmpty) return path;

    // Convert and filter micro-distance jitter
    final List<Offset> pts = [];
    for (int i = 0; i < points.length; i++) {
      final off = points[i].toOffset(canvasSize);
      if (pts.isEmpty) {
        pts.add(off);
      } else {
        final distSq = (off - pts.last).distanceSquared;
        // Keep point if separated by at least 1.2px, or if it's the terminal endpoint
        if (distSq >= 1.44 || i == points.length - 1) {
          pts.add(off);
        }
      }
    }

    if (pts.length == 1) {
      path.addOval(Rect.fromCircle(center: pts[0], radius: 0.5));
      return path;
    }

    if (pts.length == 2) {
      path.moveTo(pts[0].dx, pts[0].dy);
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }

    path.moveTo(pts[0].dx, pts[0].dy);

    // Initial midpoint connection
    final firstMid = Offset((pts[0].dx + pts[1].dx) / 2.0, (pts[0].dy + pts[1].dy) / 2.0);
    path.lineTo(firstMid.dx, firstMid.dy);

    // Smooth quadratic bezier through successive midpoints
    for (int i = 1; i < pts.length - 1; i++) {
      final pCurrent = pts[i];
      final pNext = pts[i + 1];
      final midNext = Offset((pCurrent.dx + pNext.dx) / 2.0, (pCurrent.dy + pNext.dy) / 2.0);
      path.quadraticBezierTo(pCurrent.dx, pCurrent.dy, midNext.dx, midNext.dy);
    }

    // Connect to the final point
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }
}
