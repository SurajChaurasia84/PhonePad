import 'package:flutter/material.dart';
import '../../state/drawing_controller.dart';

class ColorPickerModal extends StatefulWidget {
  final DrawingController controller;

  const ColorPickerModal({super.key, required this.controller});

  @override
  State<ColorPickerModal> createState() => _ColorPickerModalState();
}

class _ColorPickerModalState extends State<ColorPickerModal> {
  late double _currentWidth;
  late Color _selectedColor;

  static const List<Color> _palette = [
    Colors.black87,
    Colors.white,
    Color(0xFF2563EB), // Blue
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Yellow
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF97316), // Orange
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.controller.config.penWidth;
    _selectedColor = widget.controller.config.penColor;
  }

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
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pen Settings',
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

              // Scrollable body to guarantee zero overflow in landscape
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Color Palette',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 8),

                      // Palette Wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _palette.map((color) {
                          final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedColor = color);
                              widget.controller.setPenColor(color);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3B82F6) : Colors.white24,
                                  width: isSelected ? 2.5 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 18,
                                      color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Stroke Width',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_currentWidth.toStringAsFixed(1)} px',
                            style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Stroke width preview and slider
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: Container(
                              width: _currentWidth.clamp(2.0, 24.0),
                              height: _currentWidth.clamp(2.0, 24.0),
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: Colors.white12,
                                thumbColor: Colors.white,
                                trackHeight: 3.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                              ),
                              child: Slider(
                                value: _currentWidth,
                                min: 1.0,
                                max: 18.0,
                                onChanged: (val) {
                                  setState(() => _currentWidth = val);
                                  widget.controller.setPenWidth(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
