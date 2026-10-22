import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/embedded_server.dart';

class ConnectionModal extends StatelessWidget {
  final EmbeddedServer server;
  final String ipAddress;
  final VoidCallback onToggleServer;

  const ConnectionModal({
    super.key,
    required this.server,
    required this.ipAddress,
    required this.onToggleServer,
  });

  String get connectionUrl => 'http://$ipAddress:${server.port}';
  String get fullQrUrl => '$connectionUrl?pin=${server.sessionPin}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: QR Code
              Container(
                width: 190,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: fullQrUrl,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scan to Open Whiteboard',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Right: URL, PIN, and Instructions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Connect PC Browser',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // URL Box with Copy button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PC BROWSER URL',
                                  style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  connectionUrl,
                                  style: const TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: connectionUrl));
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 6-digit Session PIN
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SESSION PIN',
                                  style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  server.sessionPin,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: server.activeClientsCount > 0
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: server.activeClientsCount > 0
                                  ? const Color(0xFF10B981).withOpacity(0.4)
                                  : Colors.white12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONNECTED PC',
                                style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${server.activeClientsCount} device',
                                style: TextStyle(
                                  color: server.activeClientsCount > 0 ? const Color(0xFF10B981) : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Helpful setup tip
                    const Text(
                      '• Both devices must be on the same Wi-Fi.\n• If PC cannot connect, turn on your Phone\'s Personal Hotspot and connect PC to it.',
                      style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                    ),

                    const Spacer(),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            onToggleServer();
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: server.isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            side: BorderSide(
                              color: server.isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                          ),
                          child: Text(server.isRunning ? 'Restart Server' : 'Start Server'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
