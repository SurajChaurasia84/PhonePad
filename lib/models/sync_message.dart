import 'drawing_point.dart';
import 'drawing_stroke.dart';
import 'drawing_shape.dart';

abstract class SyncMessage {
  final String type;
  const SyncMessage(this.type);

  Map<String, dynamic> toJson();
}

class StrokeStartMessage extends SyncMessage {
  final String id;
  final String color;
  final double width;
  final String penType;
  final double opacity;
  final double x;
  final double y;

  const StrokeStartMessage({
    required this.id,
    required this.color,
    required this.width,
    this.penType = 'pen',
    this.opacity = 1.0,
    required this.x,
    required this.y,
  }) : super('stroke_start');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'color': color,
        'width': width,
        'penType': penType,
        'opacity': opacity,
        'x': x,
        'y': y,
      };
}

class StrokePointsMessage extends SyncMessage {
  final String id;
  final List<DrawingPoint> points;

  const StrokePointsMessage({
    required this.id,
    required this.points,
  }) : super('stroke_points');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
      };
}

class StrokeEndMessage extends SyncMessage {
  final String id;

  const StrokeEndMessage({required this.id}) : super('stroke_end');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
      };
}

class StrokeEraseMessage extends SyncMessage {
  final String id;

  const StrokeEraseMessage({required this.id}) : super('stroke_erase');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
      };
}

class ShapeAddMessage extends SyncMessage {
  final DrawingShape shape;

  const ShapeAddMessage({required this.shape}) : super('shape_add');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        ...shape.toJson(),
      };
}

class PointerMoveMessage extends SyncMessage {
  final bool active;
  final double x;
  final double y;

  const PointerMoveMessage({
    required this.active,
    required this.x,
    required this.y,
  }) : super('pointer_move');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'active': active,
        'x': double.parse(x.toStringAsFixed(5)),
        'y': double.parse(y.toStringAsFixed(5)),
      };
}

class UndoMessage extends SyncMessage {
  final String? strokeId;

  const UndoMessage({this.strokeId}) : super('undo');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (strokeId != null) 'strokeId': strokeId,
      };
}

class RedoMessage extends SyncMessage {
  final dynamic item; // DrawingStroke or DrawingShape

  const RedoMessage({required this.item}) : super('redo');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'item': item is DrawingStroke ? item.toJson() : (item as DrawingShape).toJson(),
      };
}

class PhoneCanvasClearMessage extends SyncMessage {
  const PhoneCanvasClearMessage() : super('phone_canvas_clear');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

class PcCanvasClearMessage extends SyncMessage {
  const PcCanvasClearMessage() : super('pc_canvas_clear');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

class ConfigUpdateMessage extends SyncMessage {
  final String aspectRatio;
  final String bgColor;
  final bool gridMode;

  const ConfigUpdateMessage({
    required this.aspectRatio,
    required this.bgColor,
    required this.gridMode,
  }) : super('config_update');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'aspectRatio': aspectRatio,
        'bgColor': bgColor,
        'gridMode': gridMode,
      };
}

class StateSyncMessage extends SyncMessage {
  final String aspectRatio;
  final String bgColor;
  final bool gridMode;
  final List<dynamic> items;

  const StateSyncMessage({
    required this.aspectRatio,
    required this.bgColor,
    required this.gridMode,
    required this.items,
  }) : super('state_sync');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'aspectRatio': aspectRatio,
        'bgColor': bgColor,
        'gridMode': gridMode,
        'items': items.map((item) {
          if (item is DrawingStroke) return item.toJson();
          if (item is DrawingShape) return item.toJson();
          return item;
        }).toList(),
      };
}
