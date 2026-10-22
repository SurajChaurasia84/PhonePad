import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/canvas_config.dart';

class StorageService {
  static const _keyAspectRatio = 'phonepad_pref_aspect_ratio';
  static const _keyBgColor = 'phonepad_pref_bg_color';
  static const _keyPenWidth = 'phonepad_pref_pen_width';
  static const _keyPenColor = 'phonepad_pref_pen_color';
  static const _keyShowGrid = 'phonepad_pref_show_grid';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  CanvasConfig loadConfig() {
    if (_prefs == null) return CanvasConfig();

    final ratioStr = _prefs!.getString(_keyAspectRatio);
    final ratio = CanvasAspectRatio.values.firstWhere(
      (r) => r.label == ratioStr,
      orElse: () => CanvasAspectRatio.ratio16_9,
    );

    final bgStr = _prefs!.getString(_keyBgColor);
    final bg = CanvasBgColor.values.firstWhere(
      (b) => b.label == bgStr,
      orElse: () => CanvasBgColor.white,
    );

    final penWidth = _prefs!.getDouble(_keyPenWidth) ?? 4.0;
    final penColorInt = _prefs!.getInt(_keyPenColor) ?? Colors.black87.toARGB32();
    final showGrid = _prefs!.getBool(_keyShowGrid) ?? false;

    return CanvasConfig(
      aspectRatio: ratio,
      bgColor: bg,
      penWidth: penWidth,
      penColor: Color(penColorInt),
      showGrid: showGrid,
    );
  }

  Future<void> saveConfig(CanvasConfig config) async {
    if (_prefs == null) return;
    await _prefs!.setString(_keyAspectRatio, config.aspectRatio.label);
    await _prefs!.setString(_keyBgColor, config.bgColor.label);
    await _prefs!.setDouble(_keyPenWidth, config.penWidth);
    await _prefs!.setInt(_keyPenColor, config.penColor.toARGB32());
    await _prefs!.setBool(_keyShowGrid, config.showGrid);
  }
}
