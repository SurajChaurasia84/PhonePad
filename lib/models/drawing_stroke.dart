import 'dart:math';
import 'package:flutter/material.dart';
import 'drawing_point.dart';
import 'pen_type.dart';

/// Represents a freehand drawing stroke composed of normalized points.
class DrawingStroke {
  final String id;
  final Color color;
  final double width;
  final PenType penType;
  final double opacity;
  final List<DrawingPoint> points;
  final int createdAt;

  DrawingStroke({
    required this.id,
    required this.color,
    required this.width,
    this.penType = PenType.pen,
    double? opacity,
    List<DrawingPoint>? points,
    int? createdAt,
  })  : opacity = opacity ?? penType.defaultOpacity,
        points = points ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  void addPoint(DrawingPoint point) {
    points.add(point);
  }

  String get colorHex => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': colorHex,
        'width': double.parse(width.toStringAsFixed(1)),
        'penType': penType.name,
        'opacity': double.parse(opacity.toStringAsFixed(2)),
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    String hex = (json['color'] as String).replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final int colorInt = int.tryParse(hex, radix: 16) ?? 0xFF000000;

    PenType pType = PenType.pen;
    if (json['penType'] != null) {
      pType = PenType.values.firstWhere(
        (t) => t.name == json['penType'],
        orElse: () => PenType.pen,
      );
    }

    final double op = (json['opacity'] as num?)?.toDouble() ?? pType.defaultOpacity;

    return DrawingStroke(
      id: json['id'] as String,
      color: Color(colorInt),
      width: (json['width'] as num).toDouble(),
      penType: pType,
      opacity: op,
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Calculates the bounding box of the stroke in canvas coordinates.
  Rect getBoundingBox(Size canvasSize) {
    if (points.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final p in points) {
      final dx = p.x * canvasSize.width;
      final dy = p.y * canvasSize.height;
      if (dx < minX) minX = dx;
      if (dx > maxX) maxX = dx;
      if (dy < minY) minY = dy;
      if (dy > maxY) maxY = dy;
    }

    final pad = width * 2;
    return Rect.fromLTRB(
      max(0.0, minX - pad),
      max(0.0, minY - pad),
      min(canvasSize.width, maxX + pad),
      min(canvasSize.height, maxY + pad),
    );
  }
}
