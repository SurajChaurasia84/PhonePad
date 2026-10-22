import 'dart:math';
import 'package:flutter/material.dart';

enum ShapeType {
  line,
  rectangle,
  circle,
  arrow,
  text,
}

class DrawingShape {
  final String id;
  final ShapeType type;
  final Color color;
  final double width;
  final bool fill;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String? text;
  final double fontSize;

  const DrawingShape({
    required this.id,
    required this.type,
    required this.color,
    required this.width,
    this.fill = false,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.text,
    this.fontSize = 22.0,
  });

  String get colorHex => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'shapeType': type.name,
        'color': colorHex,
        'width': double.parse(width.toStringAsFixed(1)),
        'fill': fill,
        'startX': double.parse(startX.toStringAsFixed(5)),
        'startY': double.parse(startY.toStringAsFixed(5)),
        'endX': double.parse(endX.toStringAsFixed(5)),
        'endY': double.parse(endY.toStringAsFixed(5)),
        if (text != null) 'text': text,
        if (text != null) 'fontSize': fontSize,
      };

  factory DrawingShape.fromJson(Map<String, dynamic> json) {
    String hex = (json['color'] as String).replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final int colorInt = int.tryParse(hex, radix: 16) ?? 0xFF000000;

    return DrawingShape(
      id: json['id'] as String,
      type: ShapeType.values.firstWhere(
        (e) => e.name == json['shapeType'],
        orElse: () => ShapeType.rectangle,
      ),
      color: Color(colorInt),
      width: (json['width'] as num?)?.toDouble() ?? 3.0,
      fill: json['fill'] as bool? ?? false,
      startX: (json['startX'] as num).toDouble(),
      startY: (json['startY'] as num).toDouble(),
      endX: (json['endX'] as num).toDouble(),
      endY: (json['endY'] as num).toDouble(),
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22.0,
    );
  }

  Rect getBoundingBox(Size canvasSize) {
    final x1 = startX * canvasSize.width;
    final y1 = startY * canvasSize.height;
    final x2 = endX * canvasSize.width;
    final y2 = endY * canvasSize.height;

    final pad = max(width * 2, 12.0);
    return Rect.fromLTRB(
      min(x1, x2) - pad,
      min(y1, y2) - pad,
      max(x1, x2) + pad,
      max(y1, y2) + pad,
    );
  }
}
