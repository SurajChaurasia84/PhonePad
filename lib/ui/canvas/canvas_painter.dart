import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/drawing_stroke.dart';
import '../../models/drawing_shape.dart';
import '../../models/pen_type.dart';
import '../../state/drawing_controller.dart';
import '../../utils/bezier_smoother.dart';

class CanvasPainter extends CustomPainter {
  final List<dynamic> items;
  final DrawingStroke? activeStroke;
  final DrawingShape? activeShape;
  final bool isPointerActive;
  final Offset pointerPosition;
  final List<LaserPoint> laserTrail;

  CanvasPainter({
    required this.items,
    this.activeStroke,
    this.activeShape,
    this.isPointerActive = false,
    this.pointerPosition = Offset.zero,
    this.laserTrail = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Paint completed items (strokes and shapes)
    for (final item in items) {
      if (item is DrawingStroke) {
        _paintStroke(canvas, size, item);
      } else if (item is DrawingShape) {
        _paintShape(canvas, size, item);
      }
    }

    // 2. Paint active stroke if any
    if (activeStroke != null) {
      _paintStroke(canvas, size, activeStroke!);
    }

    // 3. Paint active shape preview if any
    if (activeShape != null) {
      _paintShape(canvas, size, activeShape!);
    }

    // 4. Paint laser trail and pointer if active or trailing
    if (isPointerActive || laserTrail.isNotEmpty) {
      _paintLaser(canvas, size);
    }
  }

  void _paintStroke(Canvas canvas, Size size, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final effectiveColor = stroke.color.withValues(alpha: stroke.opacity);
    final paint = Paint()
      ..color = effectiveColor
      ..strokeWidth = stroke.width
      ..strokeCap = stroke.penType == PenType.highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final p = stroke.points[0].toOffset(size);
      final dotPaint = Paint()
        ..color = effectiveColor
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, stroke.width / 2.0, dotPaint);
      return;
    }

    final path = BezierSmoother.pointsToPath(stroke.points, size);
    canvas.drawPath(path, paint);
  }

  void _paintShape(Canvas canvas, Size size, DrawingShape shape) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = shape.fill ? PaintingStyle.fill : PaintingStyle.stroke;

    final sx = shape.startX * size.width;
    final sy = shape.startY * size.height;
    final ex = shape.endX * size.width;
    final ey = shape.endY * size.height;

    switch (shape.type) {
      case ShapeType.line:
        canvas.drawLine(Offset(sx, sy), Offset(ex, ey), paint);
        break;

      case ShapeType.rectangle:
        final rect = Rect.fromPoints(Offset(sx, sy), Offset(ex, ey));
        canvas.drawRect(rect, paint);
        break;

      case ShapeType.circle:
        final rect = Rect.fromPoints(Offset(sx, sy), Offset(ex, ey));
        canvas.drawOval(rect, paint);
        break;

      case ShapeType.arrow:
        _paintArrow(canvas, Offset(sx, sy), Offset(ex, ey), shape.color, shape.width);
        break;

      case ShapeType.text:
        if (shape.text != null && shape.text!.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: shape.text,
              style: TextStyle(
                color: shape.color,
                fontSize: shape.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(sx, sy));
        }
        break;
    }
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color, double width) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    canvas.drawLine(from, to, linePaint);

    final double headLen = max(14.0, width * 3.5);
    final double angle = atan2(to.dy - from.dy, to.dx - from.dx);

    final Path headPath = Path();
    headPath.moveTo(to.dx, to.dy);
    headPath.lineTo(
      to.dx - headLen * cos(angle - pi / 6),
      to.dy - headLen * sin(angle - pi / 6),
    );
    headPath.lineTo(
      to.dx - headLen * cos(angle + pi / 6),
      to.dy - headLen * sin(angle + pi / 6),
    );
    headPath.close();

    final fillPaint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, fillPaint);
  }

  void _paintLaser(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const double lifespan = 1500.0; // 1.5 seconds glow effect

    // 1. Draw glowing trail connecting recent laser points (only within same gesture)
    if (laserTrail.length > 1) {
      for (int i = 1; i < laserTrail.length; i++) {
        final pt1 = laserTrail[i - 1];
        final pt2 = laserTrail[i];

        // Isolate strokes: Never connect points from different touches or across teleport distances!
        if (pt1.gestureId != pt2.gestureId) continue;
        if ((pt1.position - pt2.position).distance > 120.0) continue;

        final age = now - pt2.timestamp;
        final progress = (1.0 - (age / lifespan)).clamp(0.0, 1.0);

        if (progress > 0) {
          // Pure red glowing neon laser trail (NO white core)
          final glowPaint = Paint()
            ..color = const Color(0xFFFF1744).withValues(alpha: 0.65 * progress)
            ..strokeWidth = 11.0 * progress
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke;
          canvas.drawLine(pt1.position, pt2.position, glowPaint);

          final coreRedPaint = Paint()
            ..color = const Color(0xFFFF0033).withValues(alpha: 0.95 * progress)
            ..strokeWidth = 4.0 * progress
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke;
          canvas.drawLine(pt1.position, pt2.position, coreRedPaint);
        }
      }
    }

    // 2. Draw glowing pure red laser pointer head if finger is active
    if (isPointerActive) {
      _paintLaserPointer(canvas, pointerPosition);
    }
  }

  void _paintLaserPointer(Canvas canvas, Offset pos) {
    // Outer glowing halo (Pure Red gradient)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF1744).withValues(alpha: 0.85),
          const Color(0xFFFF1744).withValues(alpha: 0.35),
          const Color(0xFFFF1744).withValues(alpha: 0.0),
        ],
        stops: const [0.15, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: 24.0));
    canvas.drawCircle(pos, 24.0, glowPaint);

    // Pure red laser core (NO white point!)
    final corePaint = Paint()
      ..color = const Color(0xFFFF0033)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 5.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
