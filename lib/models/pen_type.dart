enum PenType {
  pen,
  marker,
  highlighter,
  brush;

  String get label {
    switch (this) {
      case PenType.pen:
        return 'Pen';
      case PenType.marker:
        return 'Marker';
      case PenType.highlighter:
        return 'Highlighter';
      case PenType.brush:
        return 'Brush';
    }
  }

  double get defaultOpacity {
    switch (this) {
      case PenType.pen:
        return 1.0;
      case PenType.marker:
        return 0.85;
      case PenType.highlighter:
        return 0.38;
      case PenType.brush:
        return 0.92;
    }
  }

  double get widthMultiplier {
    switch (this) {
      case PenType.pen:
        return 1.0;
      case PenType.marker:
        return 1.75;
      case PenType.highlighter:
        return 4.0;
      case PenType.brush:
        return 1.5;
    }
  }
}
