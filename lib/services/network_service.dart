import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Retrieves the active local IPv4 address (Wi-Fi or Hotspot).
  Future<String?> getLocalIpAddress() async {
    try {
      if (!kIsWeb) {
        // Try network_info_plus first
        final wifiIp = await _networkInfo.getWifiIP();
        if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
          return wifiIp;
        }

        // Fallback: enumerate network interfaces
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );

        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            // Prefer standard private LAN IPs
            if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.16.') ||
                ip.startsWith('172.20.') ||
                ip.startsWith('172.31.')) {
              return ip;
            }
          }
        }

        // Return first non-loopback if available
        if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
          return interfaces.first.addresses.first.address;
        }
      }
    } catch (e) {
      debugPrint('[NetworkService] Error getting IP: $e');
    }

    return '127.0.0.1';
  }

  /// Generates a secure, readable 6-digit session PIN.
  static String generatePin() {
    final random = Random();
    final pinNum = 100000 + random.nextInt(900000);
    return pinNum.toString();
  }
}
