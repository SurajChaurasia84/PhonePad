import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Embedded HTTP & WebSocket Server E2E Verification', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8089);
    const sessionPin = '654321';
    final clients = <WebSocket>[];

    server.listen((HttpRequest request) async {
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      if (request.uri.path == '/ws') {
        final pin = request.uri.queryParameters['pin'];
        if (pin != sessionPin) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.write('Invalid PIN');
          await request.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(request);
        clients.add(ws);
        ws.listen((data) {
          final msg = jsonDecode(data as String);
          if (msg['type'] == 'ping') {
            ws.add(jsonEncode({'type': 'pong'}));
          } else {
            for (final c in clients) {
              c.add(data);
            }
          }
        });
        return;
      }

      // Serve HTML
      request.response.headers.contentType = ContentType.html;
      request.response.write('<!DOCTYPE html><html><body><h1>PhonePad Active</h1></body></html>');
      await request.response.close();
    });

    // 1. Verify HTTP GET
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:8089/'));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    expect(res.statusCode, HttpStatus.ok);
    expect(body.contains('PhonePad Active'), isTrue);

    // 2. Verify WebSocket Auth Rejection with bad PIN
    expect(
      () async => await WebSocket.connect('ws://127.0.0.1:8089/ws?pin=wrong'),
      throwsException,
    );

    // 3. Verify WebSocket Connection with valid PIN
    final ws = await WebSocket.connect('ws://127.0.0.1:8089/ws?pin=$sessionPin');
    expect(ws.readyState, WebSocket.open);

    // 4. Verify Ping / Pong latency check
    ws.add(jsonEncode({'type': 'ping'}));
    final firstMsg = await ws.first;
    final parsed = jsonDecode(firstMsg as String);
    expect(parsed['type'], 'pong');

    await ws.close();
    await server.close();
    client.close();
  });
}
