import 'package:flutter/material.dart';
import '../../state/drawing_controller.dart';
import 'canvas_painter.dart';
import 'grid_painter.dart';

class DrawingCanvas extends StatefulWidget {
  final DrawingController controller;
  final Size canvasSize;

  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.canvasSize,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  int? _activePointerId;

  @override
  Widget build(BuildContext context) {
    final isDarkBg = widget.controller.config.bgColor.color.computeLuminance() < 0.5;

    return Center(
      child: Transform.scale(
        scale: widget.controller.zoomScale,
        alignment: Alignment.center,
        child: Container(
          width: widget.canvasSize.width,
          height: widget.canvasSize.height,
          decoration: BoxDecoration(
            color: widget.controller.config.bgColor.color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Grid Layer
              if (widget.controller.config.showGrid)
                CustomPaint(
                  painter: GridPainter(isDark: isDarkBg),
                  size: widget.canvasSize,
                ),

              // Drawing Touch Layer
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (_activePointerId != null) {
                    widget.controller.onTouchEnd(widget.canvasSize);
                  }
                  _activePointerId = event.pointer;
                  widget.controller.onTouchStart(
                    event.localPosition,
                    widget.canvasSize,
                    pressure: event.pressure > 0 ? event.pressure : 1.0,
                  );
                },
                onPointerMove: (event) {
                  if (_activePointerId == event.pointer) {
                    widget.controller.onTouchUpdate(
                      event.localPosition,
                      widget.canvasSize,
                      pressure: event.pressure > 0 ? event.pressure : 1.0,
                    );
                  }
                },
                onPointerUp: (event) {
                  if (_activePointerId == event.pointer) {
                    _activePointerId = null;
                    widget.controller.onTouchEnd(widget.canvasSize);
                  }
                },
                onPointerCancel: (event) {
                  if (_activePointerId == event.pointer) {
                    _activePointerId = null;
                    widget.controller.onTouchEnd(widget.canvasSize);
                  }
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      items: widget.controller.items,
                      activeStroke: widget.controller.currentStroke,
                      activeShape: widget.controller.currentShape,
                      isPointerActive: widget.controller.isPointerActive,
                      pointerPosition: widget.controller.pointerPosition,
                      laserTrail: widget.controller.laserTrail,
                    ),
                    size: widget.canvasSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
