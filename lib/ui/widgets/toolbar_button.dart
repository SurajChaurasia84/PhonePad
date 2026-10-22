import 'package:flutter/material.dart';

class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDanger;
  final Color? customIconColor;
  final Widget? trailingBadge;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isSelected = false,
    this.isDanger = false,
    this.customIconColor,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;

    Color bg = Colors.transparent;
    Color iconColor = customIconColor ?? (isDanger ? const Color(0xFFEF4444) : Colors.white70);

    if (isSelected) {
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.28);
      iconColor = const Color(0xFF60A5FA);
    } else if (isDanger) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
    }

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          splashColor: Colors.white12,
          highlightColor: Colors.white10,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 35,
            height: 35,
            margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 1),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.7), width: 1.5)
                  : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isEnabled ? iconColor : Colors.white24,
                ),
                if (trailingBadge != null)
                  Positioned(
                    right: 2.5,
                    bottom: 2.5,
                    child: trailingBadge!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
