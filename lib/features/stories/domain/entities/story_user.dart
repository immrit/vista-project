import 'package:flutter/foundation.dart';
import 'story.dart';

/// مدل کاربر با استوری‌ها
@immutable
class StoryUser {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final bool isPremium;
  final List<Story> stories;
  final DateTime? lastStoryAt;

  const StoryUser({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.isPremium = false,
    this.stories = const [],
    this.lastStoryAt,
  });

  /// آیا همه استوری‌ها دیده شده؟
  bool get allViewed => stories.every((s) => s.isViewed);

  /// آیا استوری دیده نشده دارد؟
  bool get hasUnseenStories => stories.any((s) => !s.isViewed);

  /// تعداد استوری‌های دیده نشده
  int get unseenCount => stories.where((s) => !s.isViewed).length;

  /// آیا کاربر فعلی است؟
  bool isCurrentUser(String currentUserId) => id == currentUserId;

  StoryUser copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    bool? isPremium,
    List<Story>? stories,
    DateTime? lastStoryAt,
  }) {
    return StoryUser(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      stories: stories ?? this.stories,
      lastStoryAt: lastStoryAt ?? this.lastStoryAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'is_premium': isPremium,
      'stories': stories.map((s) => s.toMap()).toList(),
      'last_story_at': lastStoryAt?.toIso8601String(),
    };
  }

  factory StoryUser.fromMap(Map<String, dynamic> map, {List<Story>? stories}) {
    return StoryUser(
      id: map['id'] ?? map['user_id'] ?? '',
      username: map['username'] ?? '',
      avatarUrl: map['avatar_url'] ?? map['profile_image_url'],
      isVerified: map['is_verified'] ?? false,
      isPremium: map['is_premium'] ?? map['role'] == 'premium',
      stories: stories ?? [],
      lastStoryAt: map['last_story_at'] != null
          ? DateTime.parse(map['last_story_at'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
