import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/drawing_shape.dart';
import '../../state/drawing_controller.dart';
import '../../services/embedded_server.dart';
import '../widgets/toolbar_button.dart';
import '../dialogs/connection_modal.dart';
import '../dialogs/settings_modal.dart';
import '../dialogs/text_input_modal.dart';

class LeftToolbar extends StatelessWidget {
  final DrawingController controller;
  final EmbeddedServer server;
  final String ipAddress;
  final VoidCallback onToggleServer;
  final Size currentCanvasSize;

  const LeftToolbar({
    super.key,
    required this.controller,
    required this.server,
    required this.ipAddress,
    required this.onToggleServer,
    required this.currentCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Connection Status Modal Button
              ToolbarButton(
                icon: Icons.wifi,
                tooltip: server.isRunning
                    ? 'Connected: ${server.activeClientsCount} PC (Port ${server.port})'
                    : 'Start PC Server',
                customIconColor: server.isRunning
                    ? (server.activeClientsCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                    : const Color(0xFFEF4444),
                isSelected: false,
                trailingBadge: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: server.isRunning
                        ? (server.activeClientsCount > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                        : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ConnectionModal(
                      server: server,
                      ipAddress: ipAddress,
                      onToggleServer: onToggleServer,
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white12, height: 12),

              // 2. Pointer Mode (Laser Pointer)
              ToolbarButton(
                icon: Icons.flare,
                tooltip: 'Laser Pointer (Highlighter)',
                isSelected: controller.activeTool == ActiveTool.pointer,
                onTap: () => controller.setTool(ActiveTool.pointer),
              ),

              // 3. Selection Tool
              ToolbarButton(
                icon: Icons.near_me,
                tooltip: 'Select Mode',
                isSelected: controller.activeTool == ActiveTool.select,
                onTap: () => controller.setTool(ActiveTool.select),
              ),

              const Divider(color: Colors.white12, height: 12),

              // 4. Straight Line Tool
              ToolbarButton(
                icon: Icons.horizontal_rule,
                tooltip: 'Straight Line',
                isSelected: controller.activeTool == ActiveTool.shape &&
                    controller.activeShapeType == ShapeType.line,
                onTap: () => controller.setShapeType(ShapeType.line),
              ),

              // 5. Rectangle Tool
              ToolbarButton(
                icon: Icons.crop_square,
                tooltip: 'Rectangle',
                isSelected: controller.activeTool == ActiveTool.shape &&
                    controller.activeShapeType == ShapeType.rectangle,
                onTap: () => controller.setShapeType(ShapeType.rectangle),
              ),

              // 6. Circle Tool
              ToolbarButton(
                icon: Icons.circle_outlined,
                tooltip: 'Circle / Ellipse',
                isSelected: controller.activeTool == ActiveTool.shape &&
                    controller.activeShapeType == ShapeType.circle,
                onTap: () => controller.setShapeType(ShapeType.circle),
              ),

              // 7. Arrow Tool
              ToolbarButton(
                icon: Icons.arrow_outward,
                tooltip: 'Arrow',
                isSelected: controller.activeTool == ActiveTool.shape &&
                    controller.activeShapeType == ShapeType.arrow,
                onTap: () => controller.setShapeType(ShapeType.arrow),
              ),

              // 8. Text Tool
              ToolbarButton(
                icon: Icons.text_fields,
                tooltip: 'Text Annotation',
                isSelected: controller.activeTool == ActiveTool.text,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TextInputModal(
                      onSubmitted: (text, fontSize) {
                        controller.addTextAnnotation(
                          text: text,
                          position: Offset(
                            currentCanvasSize.width * 0.1,
                            currentCanvasSize.height * 0.1,
                          ),
                          canvasSize: currentCanvasSize,
                          fontSize: fontSize,
                        );
                      },
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white12, height: 12),

              // 9. Grid Toggle
              ToolbarButton(
                icon: Icons.grid_on,
                tooltip: 'Toggle Grid',
                isSelected: controller.config.showGrid,
                onTap: () => controller.toggleGrid(),
              ),

              // 10. Background Selector (Cycle through White, Black, Grey, Chalkboard)
              ToolbarButton(
                icon: Icons.palette_outlined,
                tooltip: 'Background: ${controller.config.bgColor.label}',
                trailingBadge: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.config.bgColor.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 1),
                  ),
                ),
                onTap: () {
                  final values = CanvasBgColor.values;
                  final nextIdx = (values.indexOf(controller.config.bgColor) + 1) % values.length;
                  controller.setBgColor(values[nextIdx]);
                },
              ),

              const Divider(color: Colors.white12, height: 12),

              // 11. Zoom In
              ToolbarButton(
                icon: Icons.zoom_in,
                tooltip: 'Zoom In',
                onTap: () => controller.zoomIn(),
              ),

              // 12. Zoom Out
              ToolbarButton(
                icon: Icons.zoom_out,
                tooltip: 'Zoom Out',
                onTap: () => controller.zoomOut(),
              ),

              // 13. Fit Canvas (Reset Zoom)
              ToolbarButton(
                icon: Icons.fit_screen,
                tooltip: 'Fit Canvas (100%)',
                onTap: controller.zoomScale != 1.0 ? () => controller.resetZoom() : null,
              ),

              const Divider(color: Colors.white12, height: 12),

              // 14. Settings Modal
              ToolbarButton(
                icon: Icons.settings,
                tooltip: 'Canvas Settings & Clear PC',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SettingsModal(controller: controller),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
