import 'dart:async';
import '../models/drawing_point.dart';
import '../models/drawing_stroke.dart';
import '../models/drawing_shape.dart';
import '../models/sync_message.dart';
import 'embedded_server.dart';

typedef OnPcClearRequested = void Function();

class SyncService {
  final EmbeddedServer server;
  OnPcClearRequested? onPcClearRequested;

  // Batching point buffer for smooth, low-latency transmission
  final List<DrawingPoint> _pendingPoints = [];
  String? _activeStrokeId;
  Timer? _batchTimer;

  SyncService({required this.server}) {
    server.onMessageReceived = _handleClientMessage;
  }

  void _handleClientMessage(Map<String, dynamic> message, dynamic client) {
    final type = message['type'] as String?;
    if (type == 'pc_canvas_clear') {
      onPcClearRequested?.call();
    }
  }

  /// Broadcasts full canvas state to newly connected or refreshed PC clients
  void sendFullStateSync({
    required String aspectRatio,
    required String bgColor,
    required bool gridMode,
    required List<dynamic> items,
  }) {
    server.broadcast(StateSyncMessage(
      aspectRatio: aspectRatio,
      bgColor: bgColor,
      gridMode: gridMode,
      items: items,
    ).toJson());
  }

  void notifyConfigUpdate({
    required String aspectRatio,
    required String bgColor,
    required bool gridMode,
  }) {
    server.broadcast(ConfigUpdateMessage(
      aspectRatio: aspectRatio,
      bgColor: bgColor,
      gridMode: gridMode,
    ).toJson());
  }

  void sendStrokeStart(DrawingStroke stroke) {
    _flushPendingPoints();
    _activeStrokeId = stroke.id;

    if (stroke.points.isNotEmpty) {
      final p0 = stroke.points.first;
      server.broadcast(StrokeStartMessage(
        id: stroke.id,
        color: stroke.colorHex,
        width: stroke.width,
        x: p0.x,
        y: p0.y,
      ).toJson());
    }
  }

  void sendStrokePoint(DrawingPoint point) {
    _pendingPoints.add(point);
    _batchTimer ??= Timer(const Duration(milliseconds: 16), _flushPendingPoints);
  }

  void sendStrokeEnd(String strokeId) {
    _flushPendingPoints();
    server.broadcast(StrokeEndMessage(id: strokeId).toJson());
    _activeStrokeId = null;
  }

  void _flushPendingPoints() {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingPoints.isEmpty || _activeStrokeId == null) return;

    final batch = List<DrawingPoint>.from(_pendingPoints);
    _pendingPoints.clear();

    server.broadcast(StrokePointsMessage(
      id: _activeStrokeId!,
      points: batch,
    ).toJson());
  }

  void sendStrokeErase(String strokeId) {
    server.broadcast(StrokeEraseMessage(id: strokeId).toJson());
  }

  void sendShapeAdd(DrawingShape shape) {
    server.broadcast(ShapeAddMessage(shape: shape).toJson());
  }

  void sendPointerMove({required bool active, required double x, required double y}) {
    server.broadcast(PointerMoveMessage(
      active: active,
      x: x,
      y: y,
    ).toJson());
  }

  void sendUndo({String? strokeId}) {
    server.broadcast(UndoMessage(strokeId: strokeId).toJson());
  }

  void sendRedo(dynamic item) {
    server.broadcast(RedoMessage(item: item).toJson());
  }

  void sendPhoneCanvasClear() {
    server.broadcast(const PhoneCanvasClearMessage().toJson());
  }

  void sendPcCanvasClear() {
    server.broadcast(const PcCanvasClearMessage().toJson());
  }

  void dispose() {
    _batchTimer?.cancel();
  }
}
