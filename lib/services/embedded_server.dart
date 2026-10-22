import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OnMessageReceived = void Function(Map<String, dynamic> message, WebSocket client);
typedef OnClientStatusChanged = void Function(int activeClientsCount);

class EmbeddedServer {
  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  String _sessionPin = '';
  int _port = 8080;
  bool _isRunning = false;

  OnMessageReceived? onMessageReceived;
  OnClientStatusChanged? onClientStatusChanged;

  bool get isRunning => _isRunning;
  int get port => _port;
  String get sessionPin => _sessionPin;
  int get activeClientsCount => _clients.length;

  /// Starts the embedded HTTP & WebSocket server.
  Future<bool> start({int initialPort = 8080, required String pin}) async {
    if (_isRunning) await stop();

    _sessionPin = pin;
    _port = initialPort;

    for (int p = initialPort; p < initialPort + 10; p++) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          p,
          shared: true,
        );
        _port = p;
        _isRunning = true;
        break;
      } catch (e) {
        debugPrint('[EmbeddedServer] Port $p busy, trying next...');
      }
    }

    if (_server == null) {
      debugPrint('[EmbeddedServer] Failed to bind to any port in range');
      return false;
    }

    debugPrint('[EmbeddedServer] Running on port $_port with PIN $_sessionPin');

    _server!.listen(
      _handleRequest,
      onError: (err) => debugPrint('[EmbeddedServer] Server error: $err'),
      cancelOnError: false,
    );

    return true;
  }

  /// Request routing: WebSocket vs Static web assets
  Future<void> _handleRequest(HttpRequest request) async {
    // Enable CORS for LAN access
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/ws') {
      await _handleWebSocketUpgrade(request);
      return;
    }

    // Serve static web files
    await _serveStaticAsset(request);
  }

  /// Upgrades HTTP request to WebSocket with session PIN verification
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final clientPin = request.uri.queryParameters['pin']?.trim() ?? '';

    if (clientPin != _sessionPin) {
      debugPrint('[EmbeddedServer] Rejected WebSocket: Invalid PIN "$clientPin" (expected "$_sessionPin")');
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write('Invalid PIN');
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      debugPrint('[EmbeddedServer] PC Client connected. Total: ${_clients.length}');
      onClientStatusChanged?.call(_clients.length);

      socket.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'ping') {
              socket.add(jsonEncode({'type': 'pong'}));
            } else {
              onMessageReceived?.call(json, socket);
            }
          } catch (e) {
            debugPrint('[EmbeddedServer] Error parsing client message: $e');
          }
        },
        onDone: () {
          _clients.remove(socket);
          debugPrint('[EmbeddedServer] Client disconnected. Total: ${_clients.length}');
          onClientStatusChanged?.call(_clients.length);
        },
        onError: (err) {
          _clients.remove(socket);
          debugPrint('[EmbeddedServer] Client socket error: $err');
          onClientStatusChanged?.call(_clients.length);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[EmbeddedServer] WebSocket upgrade failed: $e');
    }
  }

  /// Serves embedded assets (index.html, style.css, app.js) directly from rootBundle
  Future<void> _serveStaticAsset(HttpRequest request) async {
    String uriPath = request.uri.path;
    if (uriPath == '/' || uriPath.isEmpty) {
      uriPath = '/index.html';
    }

    String assetKey = 'assets/web$uriPath';
    String contentType = 'text/plain';

    if (uriPath.endsWith('.html')) {
      contentType = 'text/html; charset=utf-8';
    } else if (uriPath.endsWith('.css')) {
      contentType = 'text/css; charset=utf-8';
    } else if (uriPath.endsWith('.js')) {
      contentType = 'application/javascript; charset=utf-8';
    } else if (uriPath.endsWith('.svg')) {
      contentType = 'image/svg+xml';
    } else if (uriPath.endsWith('.png')) {
      contentType = 'image/png';
    }

    try {
      final byteData = await rootBundle.load(assetKey);
      final bytes = byteData.buffer.asUint8List();

      request.response.headers.contentType = ContentType.parse(contentType);
      request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
      request.response.add(bytes);
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found: $uriPath');
      await request.response.close();
    }
  }

  /// Broadcasts a JSON string or map to all authenticated PC clients
  void broadcast(dynamic message) {
    if (_clients.isEmpty) return;

    final text = message is String ? message : jsonEncode(message);
    final deadSockets = <WebSocket>[];

    for (final client in _clients) {
      try {
        if (client.readyState == WebSocket.open) {
          client.add(text);
        } else {
          deadSockets.add(client);
        }
      } catch (e) {
        deadSockets.add(client);
      }
    }

    for (final dead in deadSockets) {
      _clients.remove(dead);
    }
  }

  /// Stops server and closes all active sockets
  Future<void> stop() async {
    for (final client in _clients) {
      try {
        await client.close(WebSocketStatus.normalClosure, 'Server stopped');
      } catch (_) {}
    }
    _clients.clear();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _isRunning = false;
    onClientStatusChanged?.call(0);
    debugPrint('[EmbeddedServer] Stopped');
  }
}
