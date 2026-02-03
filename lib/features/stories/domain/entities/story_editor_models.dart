import 'package:flutter/material.dart';
import 'dart:math' as math;

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

/// نوع آیتم استوری
enum StoryItemType {
  text,
  image,
  sticker,
  drawing,
}

/// کلاس پایه برای تمام آیتم‌های استوری
abstract class StoryItem {
  /// شناسه یکتا
  final String id;

  /// نوع آیتم
  StoryItemType get type;

  /// موقعیت X (مرکز آیتم)
  double x;

  /// موقعیت Y (مرکز آیتم)
  double y;

  /// مقیاس (پیش‌فرض 1.0)
  double scale;

  /// چرخش به رادیان
  double rotation;

  /// آیا انتخاب شده؟
  bool isSelected;

  /// ترتیب لایه
  int zIndex;

  StoryItem({
    String? id,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isSelected = false,
    this.zIndex = 0,
  }) : id = id ?? _generateId();

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString() +
        math.Random().nextInt(9999).toString();
  }

  /// ماتریس تبدیل برای رندر
  Matrix4 get transformMatrix {
    return Matrix4.identity()
      ..translate(x, y)
      ..rotateZ(rotation)
      ..scale(scale);
  }

  /// کپی با مقادیر جدید
  StoryItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isSelected,
    int? zIndex,
  });

  /// تبدیل به JSON
  Map<String, dynamic> toJson();

  /// ایجاد از JSON
  static StoryItem fromJson(Map<String, dynamic> json) {
    final type = StoryItemType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => StoryItemType.text,
    );

    switch (type) {
      case StoryItemType.text:
        return TextStoryItem.fromJson(json);
      case StoryItemType.image:
        return ImageStoryItem.fromJson(json);
      case StoryItemType.sticker:
        return StickerStoryItem.fromJson(json);
      case StoryItemType.drawing:
        return TextStoryItem.fromJson(json); // Fallback
    }
  }
}

/// نوع انیمیشن متن
enum TextAnimationType {
  none,
  typewriter,
  fade,
  scale,
  slide,
}

/// آیتم متنی
class TextStoryItem extends StoryItem {
  String text;
  Color color;
  Color? backgroundColor;
  double fontSize;
  String fontFamily;
  TextAlign textAlign;
  int styleIndex;
  TextAnimationType animationType; // New field

  @override
  StoryItemType get type => StoryItemType.text;

  TextStoryItem({
    super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.isSelected,
    super.zIndex,
    required this.text,
    this.color = Colors.white,
    this.backgroundColor,
    this.fontSize = 24.0,
    this.fontFamily = 'Vazir',
    this.textAlign = TextAlign.center,
    this.styleIndex = 0,
    this.animationType = TextAnimationType.none, // Default
  });

  @override
  TextStoryItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isSelected,
    int? zIndex,
    String? text,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    String? fontFamily,
    TextAlign? textAlign,
    int? styleIndex,
    TextAnimationType? animationType, // New field parameter
  }) {
    return TextStoryItem(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      zIndex: zIndex ?? this.zIndex,
      text: text ?? this.text,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      styleIndex: styleIndex ?? this.styleIndex,
      animationType: animationType ?? this.animationType,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'z_index': zIndex,
        'text': text,
        'color': color.value,
        'background_color': backgroundColor?.value,
        'font_size': fontSize,
        'font_family': fontFamily,
        'text_align': textAlign.index,
        'style_index': styleIndex,
        'animation_type': animationType.index, // Added
      };

  factory TextStoryItem.fromJson(Map<String, dynamic> json) {
    return TextStoryItem(
      id: json['id'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['z_index'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      backgroundColor: json['background_color'] != null
          ? Color(json['background_color'] as int)
          : null,
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 24.0,
      fontFamily: json['font_family'] as String? ?? 'Vazir',
      textAlign: TextAlign.values[json['text_align'] as int? ?? 2],
      styleIndex: json['style_index'] as int? ?? 0,
      animationType: json['animation_type'] != null
          ? TextAnimationType.values[json['animation_type'] as int]
          : TextAnimationType.none, // Added
    );
  }
}

/// آیتم تصویری
class ImageStoryItem extends StoryItem {
  String imagePath;
  double width;
  double height;

  @override
  StoryItemType get type => StoryItemType.image;

  ImageStoryItem({
    super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.isSelected,
    super.zIndex,
    required this.imagePath,
    this.width = 100,
    this.height = 100,
  });

  @override
  ImageStoryItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isSelected,
    int? zIndex,
    String? imagePath,
    double? width,
    double? height,
  }) {
    return ImageStoryItem(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      zIndex: zIndex ?? this.zIndex,
      imagePath: imagePath ?? this.imagePath,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'z_index': zIndex,
        'image_path': imagePath,
        'width': width,
        'height': height,
      };

  factory ImageStoryItem.fromJson(Map<String, dynamic> json) {
    return ImageStoryItem(
      id: json['id'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['z_index'] as int? ?? 0,
      imagePath: json['image_path'] as String? ?? '',
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 100,
    );
  }
}

/// آیتم استیکر
class StickerStoryItem extends StoryItem {
  String stickerPath;
  StoryInteractionType interactionType;
  Map<String, dynamic>? interactionData;
  double width;
  double height;

  @override
  StoryItemType get type => StoryItemType.sticker;

  StickerStoryItem({
    super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.isSelected,
    super.zIndex,
    required this.stickerPath,
    this.interactionType = StoryInteractionType.none,
    this.interactionData,
    this.width = 100,
    this.height = 100,
  });

  @override
  StickerStoryItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isSelected,
    int? zIndex,
    String? stickerPath,
    StoryInteractionType? interactionType,
    Map<String, dynamic>? interactionData,
    double? width,
    double? height,
  }) {
    return StickerStoryItem(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      zIndex: zIndex ?? this.zIndex,
      stickerPath: stickerPath ?? this.stickerPath,
      interactionType: interactionType ?? this.interactionType,
      interactionData: interactionData ?? this.interactionData,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'z_index': zIndex,
        'sticker_path': stickerPath,
        'interaction_type': interactionType.name,
        'interaction_data': interactionData,
        'width': width,
        'height': height,
      };

  factory StickerStoryItem.fromJson(Map<String, dynamic> json) {
    return StickerStoryItem(
      id: json['id'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['z_index'] as int? ?? 0,
      stickerPath: json['sticker_path'] as String? ?? '',
      interactionType: StoryInteractionType.values.firstWhere(
        (e) => e.name == json['interaction_type'],
        orElse: () => StoryInteractionType.none,
      ),
      interactionData: json['interaction_data'] as Map<String, dynamic>?,
      width: (json['width'] as num?)?.toDouble() ?? 100,
      height: (json['height'] as num?)?.toDouble() ?? 100,
    );
  }
}

/// مسیر نقاشی
class DrawingPath {
  final String id;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  DrawingPath({
    String? id,
    required this.color,
    required this.strokeWidth,
    required this.points,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  DrawingPath copyWith({
    Color? color,
    double? strokeWidth,
    List<Offset>? points,
  }) {
    return DrawingPath(
      id: id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
    );
  }
}

/// Legacy Compatibility - برای سازگاری با کد قبلی
@Deprecated('Use TextStoryItem instead')
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
  int styleIndex;

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

  /// تبدیل به TextStoryItem جدید
  TextStoryItem toTextStoryItem() {
    return TextStoryItem(
      x: x,
      y: y,
      rotation: rotation,
      scale: scale,
      text: text,
      color: color,
      fontSize: fontSize,
      fontFamily: fontFamily,
      textAlign: textAlign,
      styleIndex: styleIndex,
    );
  }

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
