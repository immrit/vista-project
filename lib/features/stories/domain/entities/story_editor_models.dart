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
