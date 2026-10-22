import 'package:flutter/material.dart';
import '../../models/canvas_config.dart';
import '../../state/drawing_controller.dart';

class SettingsModal extends StatelessWidget {
  final DrawingController controller;

  const SettingsModal({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 350),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Canvas & Display Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Aspect Ratio Selection
                      const Text(
                        'Canvas Aspect Ratio (PC Matching)',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: CanvasAspectRatio.values.map((ratio) {
                          final isSelected = controller.config.aspectRatio == ratio;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: OutlinedButton(
                                onPressed: () => controller.setAspectRatio(ratio),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  backgroundColor: isSelected
                                      ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  ratio.label,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF60A5FA) : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Background Color Selection
                      const Text(
                        'Canvas Background',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: CanvasBgColor.values.map((bg) {
                          final isSelected = controller.config.bgColor == bg;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: GestureDetector(
                                onTap: () => controller.setBgColor(bg),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: bg.color,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF3B82F6) : Colors.white24,
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    bg.label,
                                    style: TextStyle(
                                      color: bg.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Math Grid Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Math Grid Lines',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Switch(
                              value: controller.config.showGrid,
                              activeThumbColor: const Color(0xFF3B82F6),
                              onChanged: (val) => controller.toggleGrid(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Dangerous Action: Clear PC Canvas
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clear PC Whiteboard',
                                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Clears all annotations from the PC browser screen.',
                                    style: TextStyle(color: Colors.white60, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                controller.clearPcCanvas();
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              child: const Text('Clear PC', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
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
