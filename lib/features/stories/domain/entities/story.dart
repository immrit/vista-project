import 'package:flutter/foundation.dart';
import '../../core/story_enums.dart';
import 'story_media.dart';

/// Entity اصلی استوری
@immutable
class Story {
  final String id;
  final String userId;
  final StoryMedia media;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final StoryPrivacyType privacyType;
  final List<String>? allowedUserIds; // برای حریم خصوصی سفارشی
  final List<String>? excludedUserIds; // کاربران حذف شده
  final int viewsCount;
  final int reactionsCount;
  final bool isViewed; // آیا کاربر فعلی دیده

  // قابلیت‌های تعاملی
  final StoryPoll? poll;
  final StoryLink? link;
  final StoryLocation? location;
  final List<StoryMention>? mentions;
  final String? musicUrl;
  final String? musicTitle;

  const Story({
    required this.id,
    required this.userId,
    required this.media,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.privacyType = StoryPrivacyType.everyone,
    this.allowedUserIds,
    this.excludedUserIds,
    this.viewsCount = 0,
    this.reactionsCount = 0,
    this.isViewed = false,
    this.poll,
    this.link,
    this.location,
    this.mentions,
    this.musicUrl,
    this.musicTitle,
  });

  /// آیا استوری منقضی شده
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// زمان باقیمانده تا انقضا
  Duration get remainingTime => expiresAt.difference(DateTime.now());

  /// آیا استوری متعلق به کاربر فعلی است
  bool isOwnedBy(String currentUserId) => userId == currentUserId;

  Story copyWith({
    String? id,
    String? userId,
    StoryMedia? media,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    StoryPrivacyType? privacyType,
    List<String>? allowedUserIds,
    List<String>? excludedUserIds,
    int? viewsCount,
    int? reactionsCount,
    bool? isViewed,
    StoryPoll? poll,
    StoryLink? link,
    StoryLocation? location,
    List<StoryMention>? mentions,
    String? musicUrl,
    String? musicTitle,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      media: media ?? this.media,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      privacyType: privacyType ?? this.privacyType,
      allowedUserIds: allowedUserIds ?? this.allowedUserIds,
      excludedUserIds: excludedUserIds ?? this.excludedUserIds,
      viewsCount: viewsCount ?? this.viewsCount,
      reactionsCount: reactionsCount ?? this.reactionsCount,
      isViewed: isViewed ?? this.isViewed,
      poll: poll ?? this.poll,
      link: link ?? this.link,
      location: location ?? this.location,
      mentions: mentions ?? this.mentions,
      musicUrl: musicUrl ?? this.musicUrl,
      musicTitle: musicTitle ?? this.musicTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': media.url,
      'media_type': media.type.name,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'privacy_type': privacyType.name,
      'allowed_user_ids': allowedUserIds,
      'excluded_user_ids': excludedUserIds,
      'views_count': viewsCount,
      'reactions_count': reactionsCount,
      'poll': poll?.toMap(),
      'link': link?.toMap(),
      'location': location?.toMap(),
      'mentions': mentions?.map((m) => m.toMap()).toList(),
      'music_url': musicUrl,
      'music_title': musicTitle,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map, {bool isViewed = false}) {
    return Story(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      media: StoryMedia(
        url: map['media_url'] ?? '',
        type: StoryMediaType.values.firstWhere(
          (e) => e.name == (map['media_type'] ?? 'image'),
          orElse: () => StoryMediaType.image,
        ),
        thumbnailUrl: map['thumbnail_url'],
      ),
      caption: map['caption'],
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(map['expires_at'] ??
          DateTime.now().add(const Duration(hours: 24)).toIso8601String()),
      privacyType: StoryPrivacyType.values.firstWhere(
        (e) => e.name == (map['privacy_type'] ?? 'everyone'),
        orElse: () => StoryPrivacyType.everyone,
      ),
      allowedUserIds: (map['allowed_user_ids'] as List?)?.cast<String>(),
      excludedUserIds: (map['excluded_user_ids'] as List?)?.cast<String>(),
      viewsCount: map['views_count'] ?? 0,
      reactionsCount: map['reactions_count'] ?? 0,
      isViewed: isViewed,
      poll: map['poll'] != null ? StoryPoll.fromMap(map['poll']) : null,
      link: map['link'] != null ? StoryLink.fromMap(map['link']) : null,
      location: map['location'] != null
          ? StoryLocation.fromMap(map['location'])
          : null,
      mentions: (map['mentions'] as List?)
          ?.map((m) => StoryMention.fromMap(m))
          .toList(),
      musicUrl: map['music_url'],
      musicTitle: map['music_title'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Story && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// نظرسنجی استوری
@immutable
class StoryPoll {
  final String question;
  final List<StoryPollOption> options;
  final DateTime? expiresAt;
  final bool isAnonymous;

  const StoryPoll({
    required this.question,
    required this.options,
    this.expiresAt,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        'expires_at': expiresAt?.toIso8601String(),
        'is_anonymous': isAnonymous,
      };

  factory StoryPoll.fromMap(Map<String, dynamic> map) => StoryPoll(
        question: map['question'] ?? '',
        options: (map['options'] as List? ?? [])
            .map((o) => StoryPollOption.fromMap(o))
            .toList(),
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'])
            : null,
        isAnonymous: map['is_anonymous'] ?? false,
      );
}

@immutable
class StoryPollOption {
  final String id;
  final String text;
  final int votes;
  final double percentage;

  const StoryPollOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.percentage = 0,
  });

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'votes': votes};
  factory StoryPollOption.fromMap(Map<String, dynamic> map) => StoryPollOption(
        id: map['id'] ?? '',
        text: map['text'] ?? '',
        votes: map['votes'] ?? 0,
        percentage: (map['percentage'] ?? 0).toDouble(),
      );
}

/// لینک استوری
@immutable
class StoryLink {
  final String url;
  final String? title;
  final String? thumbnailUrl;

  const StoryLink({required this.url, this.title, this.thumbnailUrl});

  Map<String, dynamic> toMap() =>
      {'url': url, 'title': title, 'thumbnail_url': thumbnailUrl};
  factory StoryLink.fromMap(Map<String, dynamic> map) => StoryLink(
        url: map['url'] ?? '',
        title: map['title'],
        thumbnailUrl: map['thumbnail_url'],
      );
}

/// لوکیشن استوری
@immutable
class StoryLocation {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  const StoryLocation({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'address': address,
      };

  factory StoryLocation.fromMap(Map<String, dynamic> map) => StoryLocation(
        latitude: (map['latitude'] ?? 0).toDouble(),
        longitude: (map['longitude'] ?? 0).toDouble(),
        name: map['name'],
        address: map['address'],
      );
}

/// منشن کاربر در استوری
@immutable
class StoryMention {
  final String userId;
  final String username;
  final double x; // موقعیت X (0-1)
  final double y; // موقعیت Y (0-1)

  const StoryMention({
    required this.userId,
    required this.username,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'username': username,
        'x': x,
        'y': y,
      };

  factory StoryMention.fromMap(Map<String, dynamic> map) => StoryMention(
        userId: map['user_id'] ?? '',
        username: map['username'] ?? '',
        x: (map['x'] ?? 0).toDouble(),
        y: (map['y'] ?? 0).toDouble(),
      );
}
