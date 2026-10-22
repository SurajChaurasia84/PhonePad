import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/canvas_config.dart';
import '../models/drawing_point.dart';
import '../models/drawing_stroke.dart';
import '../models/drawing_shape.dart';
import '../models/pen_type.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';
import '../utils/geometry_utils.dart';

class LaserPoint {
  final Offset position;
  final int timestamp;
  final int gestureId;
  const LaserPoint(this.position, this.timestamp, {this.gestureId = 0});
}

class DrawingController extends ChangeNotifier {
  final SyncService syncService;
  final StorageService storageService;

  CanvasConfig config = CanvasConfig();
  ActiveTool activeTool = ActiveTool.pen;
  PenType activePenType = PenType.pen;
  ShapeType activeShapeType = ShapeType.rectangle;
  int _laserGestureId = 0;

  // Drawing elements
  final List<dynamic> _items = []; // Can contain DrawingStroke or DrawingShape
  final List<dynamic> _redoStack = [];

  DrawingStroke? _currentStroke;
  DrawingShape? _currentShape;

  // Zoom & Pan
  double zoomScale = 1.0;
  Offset panOffset = Offset.zero;

  // Laser Pointer
  bool isPointerActive = false;
  Offset pointerPosition = Offset.zero;
  final List<LaserPoint> laserTrail = [];
  Timer? _laserFadeTimer;

  void _startLaserFadeLoop() {
    _laserFadeTimer ??= Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      laserTrail.removeWhere((p) => now - p.timestamp > 1500);
      if (laserTrail.isEmpty && !isPointerActive) {
        timer.cancel();
        _laserFadeTimer = null;
      }
      notifyListeners();
    });
  }

  // Cumulative PC elements (tracks what has been sent to PC so state sync works on refresh)
  final List<dynamic> _pcItems = [];
  int currentSlideNumber = 1;

  DrawingController({
    required this.syncService,
    required this.storageService,
  }) {
    config = storageService.loadConfig();
    syncService.onPcClearRequested = clearPcCanvas;
    syncService.onNewSlideRequested = (sNum) => createNewSlide(fromRemote: true, remoteSlideNum: sNum);
  }

  List<dynamic> get items => List.unmodifiable(_items);
  DrawingStroke? get currentStroke => _currentStroke;
  DrawingShape? get currentShape => _currentShape;

  bool get canUndo => _items.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // --- Tool & Config Updates ---
  void setTool(ActiveTool tool) {
    if (activeTool == tool) return;
    activeTool = tool;
    if (activeTool != ActiveTool.pointer) {
      isPointerActive = false;
    }
    notifyListeners();
  }

  void setShapeType(ShapeType type) {
    activeShapeType = type;
    activeTool = ActiveTool.shape;
    notifyListeners();
  }

  void setPenType(PenType type) {
    activePenType = type;
    activeTool = ActiveTool.pen;
    notifyListeners();
  }

  void setPenColor(Color color) {
    config.penColor = color;
    storageService.saveConfig(config);
    notifyListeners();
  }

  void setPenWidth(double width) {
    config.penWidth = width;
    storageService.saveConfig(config);
    notifyListeners();
  }

  void setAspectRatio(CanvasAspectRatio ratio) {
    config.aspectRatio = ratio;
    storageService.saveConfig(config);
    syncService.notifyConfigUpdate(
      aspectRatio: config.aspectRatio.label,
      bgColor: config.bgColor.hex,
      gridMode: config.showGrid,
    );
    notifyListeners();
  }

  void setBgColor(CanvasBgColor bg) {
    config.bgColor = bg;
    // Auto-adjust default pen color for high contrast if pen color matches old bg
    if (bg == CanvasBgColor.black || bg == CanvasBgColor.green) {
      if (config.penColor == Colors.black || config.penColor == Colors.black87) {
        config.penColor = Colors.white;
      }
    } else {
      if (config.penColor == Colors.white) {
        config.penColor = Colors.black87;
      }
    }
    storageService.saveConfig(config);
    syncService.notifyConfigUpdate(
      aspectRatio: config.aspectRatio.label,
      bgColor: config.bgColor.hex,
      gridMode: config.showGrid,
    );
    notifyListeners();
  }

  void toggleGrid() {
    config.showGrid = !config.showGrid;
    storageService.saveConfig(config);
    syncService.notifyConfigUpdate(
      aspectRatio: config.aspectRatio.label,
      bgColor: config.bgColor.hex,
      gridMode: config.showGrid,
    );
    notifyListeners();
  }

  // --- Zoom & Pan ---
  void zoomIn() {
    zoomScale = min(5.0, zoomScale + 0.25);
    notifyListeners();
  }

  void zoomOut() {
    zoomScale = max(0.5, zoomScale - 0.25);
    if (zoomScale == 1.0) panOffset = Offset.zero;
    notifyListeners();
  }

  void resetZoom() {
    zoomScale = 1.0;
    panOffset = Offset.zero;
    notifyListeners();
  }

  // --- Touch Event Handlers ---
  void onTouchStart(Offset localPosition, Size canvasSize, {double pressure = 1.0}) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    // Safety check: Finalize any lingering unended stroke so lifting finger never connects to the next touch
    if (_currentStroke != null) {
      _items.add(_currentStroke);
      _pcItems.add(_currentStroke);
      _redoStack.clear();
      syncService.sendStrokeEnd(_currentStroke!.id);
      _currentStroke = null;
    }

    final normPoint = DrawingPoint.fromOffset(localPosition, canvasSize, pressure: pressure);

    switch (activeTool) {
      case ActiveTool.pen:
        final strokeId = 's_${DateTime.now().microsecondsSinceEpoch}';
        final effectiveWidth = config.penWidth * activePenType.widthMultiplier;
        final effectiveOpacity = activePenType.defaultOpacity;
        _currentStroke = DrawingStroke(
          id: strokeId,
          color: config.penColor,
          width: effectiveWidth,
          penType: activePenType,
          opacity: effectiveOpacity,
          points: [normPoint],
        );
        syncService.sendStrokeStart(_currentStroke!);
        notifyListeners();
        break;

      case ActiveTool.eraser:
        _eraseAtPoint(localPosition, canvasSize);
        break;

      case ActiveTool.shape:
        final shapeId = 'sh_${DateTime.now().microsecondsSinceEpoch}';
        _currentShape = DrawingShape(
          id: shapeId,
          type: activeShapeType,
          color: config.penColor,
          width: config.penWidth,
          startX: normPoint.x,
          startY: normPoint.y,
          endX: normPoint.x,
          endY: normPoint.y,
        );
        notifyListeners();
        break;

      case ActiveTool.pointer:
        isPointerActive = true;
        _laserGestureId++;
        pointerPosition = localPosition;
        laserTrail.add(LaserPoint(
          localPosition,
          DateTime.now().millisecondsSinceEpoch,
          gestureId: _laserGestureId,
        ));
        _startLaserFadeLoop();
        syncService.sendPointerMove(active: true, x: normPoint.x, y: normPoint.y);
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void onTouchUpdate(Offset localPosition, Size canvasSize, {double pressure = 1.0}) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normPoint = DrawingPoint.fromOffset(localPosition, canvasSize, pressure: pressure);

    switch (activeTool) {
      case ActiveTool.pen:
        if (_currentStroke != null) {
          _currentStroke!.addPoint(normPoint);
          syncService.sendStrokePoint(normPoint);
          notifyListeners();
        }
        break;

      case ActiveTool.eraser:
        _eraseAtPoint(localPosition, canvasSize);
        break;

      case ActiveTool.shape:
        if (_currentShape != null) {
          _currentShape = DrawingShape(
            id: _currentShape!.id,
            type: _currentShape!.type,
            color: _currentShape!.color,
            width: _currentShape!.width,
            startX: _currentShape!.startX,
            startY: _currentShape!.startY,
            endX: normPoint.x,
            endY: normPoint.y,
          );
          notifyListeners();
        }
        break;

      case ActiveTool.pointer:
        pointerPosition = localPosition;
        laserTrail.add(LaserPoint(
          localPosition,
          DateTime.now().millisecondsSinceEpoch,
          gestureId: _laserGestureId,
        ));
        _startLaserFadeLoop();
        syncService.sendPointerMove(active: true, x: normPoint.x, y: normPoint.y);
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void onTouchEnd(Size canvasSize) {
    switch (activeTool) {
      case ActiveTool.pen:
        if (_currentStroke != null) {
          _items.add(_currentStroke);
          _pcItems.add(_currentStroke);
          _redoStack.clear();
          syncService.sendStrokeEnd(_currentStroke!.id);
          _currentStroke = null;
          notifyListeners();
        }
        break;

      case ActiveTool.shape:
        if (_currentShape != null) {
          _items.add(_currentShape);
          _pcItems.add(_currentShape);
          _redoStack.clear();
          syncService.sendShapeAdd(_currentShape!);
          _currentShape = null;
          notifyListeners();
        }
        break;

      case ActiveTool.pointer:
        isPointerActive = false;
        syncService.sendPointerMove(active: false, x: 0, y: 0);
        notifyListeners();
        break;

      default:
        break;
    }
  }

  // --- Stroke-level Eraser ---
  void _eraseAtPoint(Offset localPosition, Size canvasSize) {
    int eraseIndex = -1;
    String? erasedId;

    for (int i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (item is DrawingStroke) {
        if (GeometryUtils.strokeHitsPoint(item, localPosition, canvasSize)) {
          eraseIndex = i;
          erasedId = item.id;
          break;
        }
      } else if (item is DrawingShape) {
        final bbox = item.getBoundingBox(canvasSize);
        if (bbox.contains(localPosition)) {
          eraseIndex = i;
          erasedId = item.id;
          break;
        }
      }
    }

    if (eraseIndex != -1 && erasedId != null) {
      _items.removeAt(eraseIndex);
      _pcItems.removeWhere((it) => it.id == erasedId);
      _redoStack.clear();
      syncService.sendStrokeErase(erasedId);
      notifyListeners();
    }
  }

  // --- Text Annotation ---
  void addTextAnnotation({
    required String text,
    required Offset position,
    required Size canvasSize,
    double fontSize = 24.0,
  }) {
    if (text.trim().isEmpty) return;
    final norm = DrawingPoint.fromOffset(position, canvasSize);
    final shape = DrawingShape(
      id: 'txt_${DateTime.now().microsecondsSinceEpoch}',
      type: ShapeType.text,
      color: config.penColor,
      width: 1.0,
      startX: norm.x,
      startY: norm.y,
      endX: norm.x,
      endY: norm.y,
      text: text,
      fontSize: fontSize,
    );

    _items.add(shape);
    _pcItems.add(shape);
    _redoStack.clear();
    syncService.sendShapeAdd(shape);
    notifyListeners();
  }

  // --- Undo / Redo ---
  void undo() {
    if (!canUndo) return;
    final lastItem = _items.removeLast();
    _pcItems.removeWhere((it) => it.id == lastItem.id);
    _redoStack.add(lastItem);

    final strokeId = lastItem is DrawingStroke
        ? lastItem.id
        : (lastItem as DrawingShape).id;
    syncService.sendUndo(strokeId: strokeId);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final item = _redoStack.removeLast();
    _items.add(item);
    _pcItems.add(item);
    syncService.sendRedo(item);
    notifyListeners();
  }

  // --- Clear Operations (Primary Teaching Feature) ---

  /// Clears only the phone canvas to start the next slide or equation.
  /// PC Whiteboard retains all notes unless Clear PC Canvas is pressed.
  void clearPhoneCanvas() {
    _items.clear();
    _redoStack.clear();
    _currentStroke = null;
    _currentShape = null;
    syncService.sendPhoneCanvasClear();
    notifyListeners();
  }

  /// Explicitly clears the PC whiteboard notes.
  void clearPcCanvas() {
    _pcItems.clear();
    syncService.sendPcCanvasClear();
    notifyListeners();
  }

  /// Creates a fresh new slide on both Phone and PC with empty background.
  void createNewSlide({bool fromRemote = false, int? remoteSlideNum}) {
    _items.clear();
    _pcItems.clear();
    _redoStack.clear();
    _currentStroke = null;
    _currentShape = null;

    if (remoteSlideNum != null) {
      currentSlideNumber = remoteSlideNum;
    } else {
      currentSlideNumber++;
    }

    if (!fromRemote) {
      syncService.sendNewSlide(currentSlideNumber);
    }
    notifyListeners();
  }

  /// Syncs current accumulated PC state when a PC browser connects/reconnects
  void syncStateToPc() {
    syncService.sendFullStateSync(
      aspectRatio: config.aspectRatio.label,
      bgColor: config.bgColor.hex,
      gridMode: config.showGrid,
      items: _pcItems.isNotEmpty ? _pcItems : _items,
    );
  }

  @override
  void dispose() {
    _laserFadeTimer?.cancel();
    super.dispose();
  }
}
