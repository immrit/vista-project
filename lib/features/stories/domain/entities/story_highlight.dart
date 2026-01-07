import 'package:flutter/foundation.dart';
import 'story.dart';

/// مدل Highlight (استوری‌های دائمی)
@immutable
class StoryHighlight {
  final String id;
  final String userId;
  final String title;
  final String? coverUrl;
  final List<Story> stories;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int order; // ترتیب نمایش

  const StoryHighlight({
    required this.id,
    required this.userId,
    required this.title,
    this.coverUrl,
    this.stories = const [],
    required this.createdAt,
    required this.updatedAt,
    this.order = 0,
  });

  /// کاور پیش‌فرض (اولین استوری)
  String? get defaultCover => coverUrl ?? stories.firstOrNull?.media.url;

  StoryHighlight copyWith({
    String? id,
    String? userId,
    String? title,
    String? coverUrl,
    List<Story>? stories,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
  }) {
    return StoryHighlight(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      stories: stories ?? this.stories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'cover_url': coverUrl,
      'story_ids': stories.map((s) => s.id).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order': order,
    };
  }

  factory StoryHighlight.fromMap(Map<String, dynamic> map,
      {List<Story>? stories}) {
    return StoryHighlight(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      coverUrl: map['cover_url'],
      stories: stories ?? [],
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
      order: map['order'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryHighlight && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
