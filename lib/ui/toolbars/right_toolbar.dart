import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../models/pen_type.dart';
import '../../state/drawing_controller.dart';
import '../widgets/toolbar_button.dart';
import '../dialogs/color_picker_modal.dart';

class RightToolbar extends StatelessWidget {
  final DrawingController controller;

  const RightToolbar({super.key, required this.controller});

  IconData _iconForPenType(PenType type) {
    switch (type) {
      case PenType.pen:
        return Icons.edit;
      case PenType.marker:
        return Icons.draw;
      case PenType.highlighter:
        return Icons.border_color;
      case PenType.brush:
        return Icons.brush;
    }
  }

  @override
  Widget build(BuildContext context) {
    final penIcon = _iconForPenType(controller.activePenType);

    return Container(
      width: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.08)),
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
              // 1. Undo
              ToolbarButton(
                icon: Icons.undo,
                tooltip: 'Undo (Ctrl+Z)',
                onTap: controller.canUndo ? () => controller.undo() : null,
              ),

              // 2. Redo
              ToolbarButton(
                icon: Icons.redo,
                tooltip: 'Redo (Ctrl+Y)',
                onTap: controller.canRedo ? () => controller.redo() : null,
              ),

              const Divider(color: Colors.white12, height: 10),

              // 3. Dynamic Pen Tool Button:
              // - Displays icon of the currently selected pen type (Pen, Marker, Highlighter, Brush)
              // - Tapping directly opens Pen Settings (Type, Color, Width)
              ToolbarButton(
                icon: penIcon,
                tooltip: 'Pen Settings (${controller.activePenType.label})',
                isSelected: controller.activeTool == ActiveTool.pen,
                trailingBadge: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.config.penColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
                onTap: () {
                  controller.setTool(ActiveTool.pen);
                  showDialog(
                    context: context,
                    builder: (ctx) => ColorPickerModal(controller: controller),
                  );
                },
              ),

              // 4. Stroke-Level Eraser
              ToolbarButton(
                icon: Icons.auto_fix_normal,
                tooltip: 'Stroke Eraser',
                isSelected: controller.activeTool == ActiveTool.eraser,
                onTap: () => controller.setTool(ActiveTool.eraser),
              ),

              const Divider(color: Colors.white12, height: 10),

              // 5. New Slide (+) Button:
              // Creates a fresh slide on both PC and Phone with empty background
              ToolbarButton(
                icon: Icons.add_circle_outline,
                tooltip: 'New Slide (+) — Slide ${controller.currentSlideNumber + 1}',
                customIconColor: const Color(0xFF10B981),
                onTap: () {
                  controller.createNewSlide();
                },
              ),

              const Divider(color: Colors.white12, height: 10),

              // 6. Clear Phone Canvas (Primary Teaching Feature)
              ToolbarButton(
                icon: Icons.cleaning_services_rounded,
                tooltip: 'Clear Phone Canvas (Keep PC)',
                customIconColor: const Color(0xFFF59E0B),
                onTap: () {
                  controller.clearPhoneCanvas();
                },
              ),

              const SizedBox(height: 2),

              // 7. Clear PC Canvas (Distinct Action)
              ToolbarButton(
                icon: Icons.desktop_access_disabled,
                tooltip: 'Clear PC Whiteboard',
                isDanger: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF161B22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      title: const Text('Clear PC Whiteboard?', style: TextStyle(color: Colors.white, fontSize: 16)),
                      content: const Text(
                        'This will erase all notes from the connected PC browser screen.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            controller.clearPcCanvas();
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear PC'),
                        ),
                      ],
                    ),
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
