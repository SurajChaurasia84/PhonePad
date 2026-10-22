import 'dart:math';
import 'dart:ui';
import '../models/drawing_stroke.dart';

class GeometryUtils {
  /// Computes the shortest distance from point [p] to the line segment between [v] and [w].
  static double distanceToSegment(Offset p, Offset v, Offset w) {
    final double l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
    if (l2 == 0) return (p - v).distance;

    // Consider the line extending the segment, parameterized as v + t (w - v).
    // We find projection of point p onto the line.
    // It falls where t = [(p-v) . (w-v)] / |w-v|^2
    // We clamp t from [0,1] to handle points outside the segment vw.
    final double t = max(0.0, min(1.0, ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2));
    final Offset projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distance;
  }

  /// Checks if touch point [touch] hits any segment of [stroke] within [tolerance].
  static bool strokeHitsPoint(DrawingStroke stroke, Offset touch, Size canvasSize, {double tolerance = 18.0}) {
    if (stroke.points.isEmpty) return false;

    // Fast bounding box rejection check
    final Rect bbox = stroke.getBoundingBox(canvasSize);
    if (!bbox.inflate(tolerance).contains(touch)) {
      return false;
    }

    final effectiveTolerance = max(tolerance, stroke.width * 1.5);

    // Single point stroke check
    if (stroke.points.length == 1) {
      final p = stroke.points[0].toOffset(canvasSize);
      return (touch - p).distance <= effectiveTolerance;
    }

    // Segment distance check
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final v = stroke.points[i].toOffset(canvasSize);
      final w = stroke.points[i + 1].toOffset(canvasSize);
      if (distanceToSegment(touch, v, w) <= effectiveTolerance) {
        return true;
      }
    }

    return false;
  }

  /// Calculates the aspect ratio fit size inside an available bounding container.
  static Size calculateFitSize(double availableWidth, double availableHeight, double targetRatio) {
    double targetWidth = availableWidth;
    double targetHeight = targetWidth / targetRatio;

    if (targetHeight > availableHeight) {
      targetHeight = availableHeight;
      targetWidth = targetHeight * targetRatio;
    }

    return Size(max(10.0, targetWidth), max(10.0, targetHeight));
  }
}
