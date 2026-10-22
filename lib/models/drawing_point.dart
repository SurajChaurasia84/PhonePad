import 'dart:ui';

/// Represents a 2D coordinate on the canvas, normalized between 0.0 and 1.0.
/// Normalization ensures strokes map consistently across different screen sizes and aspect ratios.
class DrawingPoint {
  final double x;
  final double y;
  final double pressure;
  final int timestamp;

  const DrawingPoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    int? timestamp,
  }) : timestamp = timestamp ?? 0;

  Map<String, dynamic> toJson() => {
        'x': double.parse(x.toStringAsFixed(5)),
        'y': double.parse(y.toStringAsFixed(5)),
        if (pressure != 1.0) 'p': double.parse(pressure.toStringAsFixed(2)),
      };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) => DrawingPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
      );

  Offset toOffset(Size canvasSize) => Offset(x * canvasSize.width, y * canvasSize.height);

  static DrawingPoint fromOffset(Offset offset, Size canvasSize, {double pressure = 1.0}) {
    final double normX = (offset.dx / canvasSize.width).clamp(0.0, 1.0);
    final double normY = (offset.dy / canvasSize.height).clamp(0.0, 1.0);
    return DrawingPoint(
      x: normX,
      y: normY,
      pressure: pressure,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
