import 'package:flutter/material.dart';

/// نوع استیکر تعاملی
enum StoryInteractionType {
  none,
  location,
  mention,
  hashtag,
  link,
  poll,
  question,
  countdown,
  music,
  gif,
  weather,
  date,
}

/// المان متنی یا استیکر در استوری
class StoryElement {
  String text;
  double x;
  double y;
  double rotation;
  double scale;
  Color color;
  double fontSize;
  String fontFamily;
  TextAlign textAlign;
  StoryInteractionType interactionType;
  Map<String, dynamic>? interactionData;

  StoryElement({
    required this.text,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.scale = 1,
    required this.color,
    required this.fontSize,
    this.fontFamily = 'Vazir',
    this.textAlign = TextAlign.center,
    this.interactionType = StoryInteractionType.none,
    this.interactionData,
    this.styleIndex = 0,
  });

  int styleIndex;

  factory StoryElement.fromJson(Map<String, dynamic> json) {
    return StoryElement(
      text: json['text'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 20.0,
      fontFamily: json['font_family'] as String? ?? 'Vazir',
      textAlign: TextAlign.values[json['text_align'] as int? ?? 2],
      interactionType: StoryInteractionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StoryInteractionType.none,
      ),
      interactionData: json['data'] as Map<String, dynamic>?,
      styleIndex: json['style_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'rotation': rotation,
      'scale': scale,
      'color': color.value,
      'font_size': fontSize,
      'font_family': fontFamily,
      'text_align': textAlign.index,
      'type': interactionType.name,
      'data': interactionData,
      'style_index': styleIndex,
    };
  }
}

/// مسیر نقاشی
class DrawingPath {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  DrawingPath({
    required this.color,
    required this.strokeWidth,
    required this.points,
  });
}
