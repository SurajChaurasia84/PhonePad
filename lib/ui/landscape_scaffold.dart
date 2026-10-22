import 'package:flutter/material.dart';
import '../state/drawing_controller.dart';
import '../services/embedded_server.dart';
import '../utils/geometry_utils.dart';
import 'canvas/drawing_canvas.dart';
import 'toolbars/left_toolbar.dart';
import 'toolbars/right_toolbar.dart';

class LandscapeScaffold extends StatelessWidget {
  final DrawingController controller;
  final EmbeddedServer server;
  final String ipAddress;
  final VoidCallback onToggleServer;

  const LandscapeScaffold({
    super.key,
    required this.controller,
    required this.server,
    required this.ipAddress,
    required this.onToggleServer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              const double leftToolbarWidth = 44.0;
              const double rightToolbarWidth = 44.0;
              const double padding = 8.0;

              final double availableWidth = constraints.maxWidth - leftToolbarWidth - rightToolbarWidth - (padding * 2);
              final double availableHeight = constraints.maxHeight - (padding * 2);

              final Size canvasSize = GeometryUtils.calculateFitSize(
                availableWidth,
                availableHeight,
                controller.config.aspectRatio.value,
              );

              return Row(
                children: [
                  // Left Toolbar (Teaching Tools)
                  LeftToolbar(
                    controller: controller,
                    server: server,
                    ipAddress: ipAddress,
                    onToggleServer: onToggleServer,
                    currentCanvasSize: canvasSize,
                  ),

                  // Central Canvas Viewport
                  Expanded(
                    child: Container(
                      color: const Color(0xFF0D1117),
                      padding: const EdgeInsets.all(padding),
                      alignment: Alignment.center,
                      child: DrawingCanvas(
                        controller: controller,
                        canvasSize: canvasSize,
                      ),
                    ),
                  ),

                  // Right Toolbar (Drawing Controls)
                  RightToolbar(
                    controller: controller,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
