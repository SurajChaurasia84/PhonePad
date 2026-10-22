import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final bool isServerRunning;
  final int connectedClients;
  final VoidCallback onTap;

  const StatusBadge({
    super.key,
    required this.isServerRunning,
    required this.connectedClients,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor = const Color(0xFFEF4444);
    String label = 'Offline';

    if (isServerRunning) {
      if (connectedClients > 0) {
        dotColor = const Color(0xFF10B981);
        label = 'PC ($connectedClients)';
      } else {
        dotColor = const Color(0xFFF59E0B);
        label = 'Waiting';
      }
    }

    return Tooltip(
      message: 'Connection status & pairing QR',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: connectedClients > 0
                      ? [
                          BoxShadow(
                            color: dotColor.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
