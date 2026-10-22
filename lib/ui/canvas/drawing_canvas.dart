import 'package:flutter/material.dart';
import '../../state/drawing_controller.dart';
import 'canvas_painter.dart';
import 'grid_painter.dart';

class DrawingCanvas extends StatelessWidget {
  final DrawingController controller;
  final Size canvasSize;

  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkBg = controller.config.bgColor.color.computeLuminance() < 0.5;

    return Center(
      child: Transform.scale(
        scale: controller.zoomScale,
        alignment: Alignment.center,
        child: Container(
          width: canvasSize.width,
          height: canvasSize.height,
          decoration: BoxDecoration(
            color: controller.config.bgColor.color,
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
              if (controller.config.showGrid)
                CustomPaint(
                  painter: GridPainter(isDark: isDarkBg),
                  size: canvasSize,
                ),

              // Drawing Touch Layer
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  controller.onTouchStart(
                    event.localPosition,
                    canvasSize,
                    pressure: event.pressure > 0 ? event.pressure : 1.0,
                  );
                },
                onPointerMove: (event) {
                  controller.onTouchUpdate(
                    event.localPosition,
                    canvasSize,
                    pressure: event.pressure > 0 ? event.pressure : 1.0,
                  );
                },
                onPointerUp: (event) {
                  controller.onTouchEnd(canvasSize);
                },
                onPointerCancel: (event) {
                  controller.onTouchEnd(canvasSize);
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      items: controller.items,
                      activeStroke: controller.currentStroke,
                      activeShape: controller.currentShape,
                      isPointerActive: controller.isPointerActive,
                      pointerPosition: controller.pointerPosition,
                      laserTrail: controller.laserTrail,
                    ),
                    size: canvasSize,
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
