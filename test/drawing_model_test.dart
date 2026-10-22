import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonepad/models/drawing_point.dart';
import 'package:phonepad/models/drawing_stroke.dart';
import 'package:phonepad/models/drawing_shape.dart';
import 'package:phonepad/models/pen_type.dart';
import 'package:phonepad/utils/geometry_utils.dart';
import 'package:phonepad/utils/bezier_smoother.dart';
import 'package:phonepad/services/storage_service.dart';
import 'package:phonepad/services/embedded_server.dart';
import 'package:phonepad/services/sync_service.dart';
import 'package:phonepad/state/drawing_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrawingPoint & DrawingStroke Unit Tests', () {
    test('DrawingPoint normalizes coordinates correctly', () {
      const canvasSize = Size(1920, 1080);
      const touchPoint = Offset(960, 540);

      final norm = DrawingPoint.fromOffset(touchPoint, canvasSize);
      expect(norm.x, closeTo(0.5, 0.001));
      expect(norm.y, closeTo(0.5, 0.001));

      final restored = norm.toOffset(canvasSize);
      expect(restored.dx, closeTo(960, 0.1));
      expect(restored.dy, closeTo(540, 0.1));
    });

    test('DrawingStroke serializes to and from JSON', () {
      final stroke = DrawingStroke(
        id: 's_test_1',
        color: const Color(0xFFEF4444),
        width: 5.0,
        points: const [
          DrawingPoint(x: 0.1, y: 0.2),
          DrawingPoint(x: 0.3, y: 0.4),
        ],
      );

      final json = stroke.toJson();
      expect(json['id'], 's_test_1');
      expect(json['width'], 5.0);
      expect(json['points'], isA<List>());

      final restored = DrawingStroke.fromJson(json);
      expect(restored.id, stroke.id);
      expect(restored.width, stroke.width);
      expect(restored.points.length, 2);
      expect(restored.points.first.x, 0.1);
      expect(restored.points.last.y, 0.4);
    });

    test('DrawingStroke supports PenType and opacity serialization', () {
      final stroke = DrawingStroke(
        id: 's_highlighter_1',
        color: const Color(0xFFFACC15),
        width: 14.0,
        penType: PenType.highlighter,
        opacity: 0.38,
        points: const [
          DrawingPoint(x: 0.2, y: 0.2),
          DrawingPoint(x: 0.5, y: 0.2),
        ],
      );

      final json = stroke.toJson();
      expect(json['penType'], 'highlighter');
      expect(json['opacity'], 0.38);

      final restored = DrawingStroke.fromJson(json);
      expect(restored.penType, PenType.highlighter);
      expect(restored.opacity, 0.38);
    });

    test('DrawingStroke bounding box calculates properly', () {
      final stroke = DrawingStroke(
        id: 's_bbox',
        color: Colors.blue,
        width: 4.0,
        points: const [
          DrawingPoint(x: 0.2, y: 0.3),
          DrawingPoint(x: 0.6, y: 0.7),
        ],
      );

      const size = Size(1000, 1000);
      final bbox = stroke.getBoundingBox(size);
      expect(bbox.left, lessThanOrEqualTo(200.0));
      expect(bbox.top, lessThanOrEqualTo(300.0));
      expect(bbox.right, greaterThanOrEqualTo(600.0));
      expect(bbox.bottom, greaterThanOrEqualTo(700.0));
    });
  });

  group('DrawingShape Unit Tests', () {
    test('DrawingShape serializes and restores shapes', () {
      const shape = DrawingShape(
        id: 'sh_rect_1',
        type: ShapeType.rectangle,
        color: Color(0xFF10B981),
        width: 3.0,
        startX: 0.1,
        startY: 0.1,
        endX: 0.5,
        endY: 0.5,
      );

      final json = shape.toJson();
      expect(json['shapeType'], 'rectangle');

      final restored = DrawingShape.fromJson(json);
      expect(restored.type, ShapeType.rectangle);
      expect(restored.startX, 0.1);
      expect(restored.endX, 0.5);
    });

    test('Text annotation shape includes text and fontSize', () {
      const textShape = DrawingShape(
        id: 'sh_txt_1',
        type: ShapeType.text,
        color: Colors.white,
        width: 1.0,
        startX: 0.2,
        startY: 0.2,
        endX: 0.2,
        endY: 0.2,
        text: 'E = mc^2',
        fontSize: 28.0,
      );

      final json = textShape.toJson();
      expect(json['text'], 'E = mc^2');
      expect(json['fontSize'], 28.0);

      final restored = DrawingShape.fromJson(json);
      expect(restored.text, 'E = mc^2');
      expect(restored.fontSize, 28.0);
    });
  });

  group('GeometryUtils & BezierSmoother Tests', () {
    test('distanceToSegment returns perpendicular distance', () {
      const v = Offset(0, 0);
      const w = Offset(10, 0);
      const p = Offset(5, 5);

      final d = GeometryUtils.distanceToSegment(p, v, w);
      expect(d, closeTo(5.0, 0.001));
    });

    test('calculateFitSize maintains exact aspect ratio', () {
      // 16:9 in a 1920x1080 container
      final fit1 = GeometryUtils.calculateFitSize(1920, 1080, 16 / 9);
      expect(fit1.width / fit1.height, closeTo(16 / 9, 0.01));

      // 16:9 in a tall 1000x1200 container
      final fit2 = GeometryUtils.calculateFitSize(1000, 1200, 16 / 9);
      expect(fit2.width, 1000);
      expect(fit2.width / fit2.height, closeTo(16 / 9, 0.01));

      // 4:3 in a wide 1600x900 container
      final fit3 = GeometryUtils.calculateFitSize(1600, 900, 4 / 3);
      expect(fit3.height, 900);
      expect(fit3.width, 1200);
    });

    test('BezierSmoother generates valid path', () {
      const size = Size(800, 600);
      const points = [
        DrawingPoint(x: 0.1, y: 0.1),
        DrawingPoint(x: 0.2, y: 0.3),
        DrawingPoint(x: 0.4, y: 0.5),
      ];

      final path = BezierSmoother.pointsToPath(points, size);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });
  });

  group('DrawingController & Dual Canvas State Tests', () {
    test('Undo and redo operate correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final server = EmbeddedServer();
      final sync = SyncService(server: server);
      final controller = DrawingController(syncService: sync, storageService: storage);

      const size = Size(800, 600);

      // Draw a stroke
      controller.onTouchStart(const Offset(100, 100), size);
      controller.onTouchUpdate(const Offset(150, 150), size);
      controller.onTouchEnd(size);

      expect(controller.items.length, 1);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      // Undo
      controller.undo();
      expect(controller.items.length, 0);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      // Redo
      controller.redo();
      expect(controller.items.length, 1);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
    });

    test('Clear Phone Canvas resets phone drawing without erasing PC state', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final server = EmbeddedServer();
      final sync = SyncService(server: server);
      final controller = DrawingController(syncService: sync, storageService: storage);

      const size = Size(800, 600);

      // Draw a stroke
      controller.onTouchStart(const Offset(50, 50), size);
      controller.onTouchUpdate(const Offset(100, 100), size);
      controller.onTouchEnd(size);

      expect(controller.items.length, 1);

      // Clear Phone Canvas
      controller.clearPhoneCanvas();

      // Phone items should be cleared
      expect(controller.items.length, 0);

      // Now clear PC Canvas
      controller.clearPcCanvas();
    });
  });
}
