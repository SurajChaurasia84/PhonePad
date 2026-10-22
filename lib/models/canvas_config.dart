import 'package:flutter/material.dart';

enum CanvasAspectRatio {
  ratio16_9('16:9', 16.0 / 9.0),
  ratio16_10('16:10', 16.0 / 10.0),
  ratio4_3('4:3', 4.0 / 3.0),
  ratio1_1('1:1', 1.0);

  final String label;
  final double value;
  const CanvasAspectRatio(this.label, this.value);
}

enum CanvasBgColor {
  white('White', Color(0xFFFFFFFF), Colors.black87),
  black('Black', Color(0xFF1E1E1E), Colors.white),
  grey('Grey', Color(0xFF2D3748), Colors.white),
  green('Chalkboard', Color(0xFF1B4332), Colors.white);

  final String label;
  final Color color;
  final Color defaultPenColor;
  const CanvasBgColor(this.label, this.color, this.defaultPenColor);

  String get hex => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

enum ActiveTool {
  pen,
  eraser,
  shape,
  text,
  pointer,
  select,
}

class CanvasConfig {
  CanvasAspectRatio aspectRatio;
  CanvasBgColor bgColor;
  bool showGrid;
  double penWidth;
  Color penColor;

  CanvasConfig({
    this.aspectRatio = CanvasAspectRatio.ratio16_9,
    this.bgColor = CanvasBgColor.white,
    this.showGrid = false,
    this.penWidth = 4.0,
    Color? penColor,
  }) : penColor = penColor ?? Colors.black87;
}
