import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../state/drawing_controller.dart';
import '../widgets/toolbar_button.dart';
import '../dialogs/color_picker_modal.dart';

class RightToolbar extends StatelessWidget {
  final DrawingController controller;

  const RightToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
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

              const Divider(color: Colors.white12, height: 12),

              // 3. Freehand Pen Tool
              ToolbarButton(
                icon: Icons.edit,
                tooltip: 'Pen Tool',
                isSelected: controller.activeTool == ActiveTool.pen,
                onTap: () => controller.setTool(ActiveTool.pen),
              ),

              // 4. Stroke-Level Eraser
              ToolbarButton(
                icon: Icons.auto_fix_normal,
                tooltip: 'Stroke Eraser',
                isSelected: controller.activeTool == ActiveTool.eraser,
                onTap: () => controller.setTool(ActiveTool.eraser),
              ),

              const Divider(color: Colors.white12, height: 12),

              // 5. Pen Color & Width Dialog
              ToolbarButton(
                icon: Icons.color_lens,
                tooltip: 'Pen Color & Width',
                trailingBadge: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: controller.config.penColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ColorPickerModal(controller: controller),
                  );
                },
              ),

              // 6. Quick Pen Width Indicator
              ToolbarButton(
                icon: Icons.line_weight,
                tooltip: 'Width: ${controller.config.penWidth.toStringAsFixed(1)}px',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ColorPickerModal(controller: controller),
                  );
                },
              ),

              const Divider(color: Colors.white12, height: 12),

              // 7. Clear Phone Canvas (Primary Teaching Feature)
              ToolbarButton(
                icon: Icons.cleaning_services_rounded,
                tooltip: 'Clear Phone Canvas (Keep PC)',
                customIconColor: const Color(0xFFF59E0B),
                onTap: () {
                  controller.clearPhoneCanvas();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Phone canvas cleared for next slide (PC notes preserved)'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
              ),

              const SizedBox(height: 4),

              // 8. Clear PC Canvas (Distinct Action)
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PC Whiteboard cleared'),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
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
