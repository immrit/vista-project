import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/story_enums.dart';
import 'story_media.dart';
import 'story_editor_models.dart';

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
  final bool viewerCanReply; // آیا بیننده مجاز به پاسخ است (از بک‌اند محاسبه می‌شود)

  // قابلیت‌های تعاملی
  final StoryPoll? poll;
  final StoryLink? link;
  final StoryLocation? location;
  final List<StoryMention>? mentions;
  final String? musicUrl;
  final String? musicTitle;

  // Interactive elements from Story Editor (stickers, text, etc.)
  final List<StoryElement>? interactiveElements;

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
    this.viewerCanReply = true,
    this.poll,
    this.link,
    this.location,
    this.mentions,
    this.musicUrl,
    this.musicTitle,
    this.interactiveElements,
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
    bool? viewerCanReply,
    StoryPoll? poll,
    StoryLink? link,
    StoryLocation? location,
    List<StoryMention>? mentions,
    String? musicUrl,
    String? musicTitle,
    List<StoryElement>? interactiveElements,
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
      viewerCanReply: viewerCanReply ?? this.viewerCanReply,
      poll: poll ?? this.poll,
      link: link ?? this.link,
      location: location ?? this.location,
      mentions: mentions ?? this.mentions,
      musicUrl: musicUrl ?? this.musicUrl,
      musicTitle: musicTitle ?? this.musicTitle,
      interactiveElements: interactiveElements ?? this.interactiveElements,
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
      'interactive_elements':
          interactiveElements?.map((e) => e.toJson()).toList(),
    };
  }

  factory Story.fromMap(Map<String, dynamic> map, {bool isViewed = false}) {
    StoryElement? parseElement(dynamic element) {
      try {
        if (element is Map<String, dynamic>) {
          return StoryElement.fromJson(element);
        }
        if (element is Map) {
          return StoryElement.fromJson(
            element.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
        if (element is String && element.trim().isNotEmpty) {
          final decoded = jsonDecode(element);
          if (decoded is Map<String, dynamic>) {
            return StoryElement.fromJson(decoded);
          }
          if (decoded is Map) {
            return StoryElement.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    List<StoryElement>? parseElements(dynamic raw) {
      if (raw is List) {
        return raw.map(parseElement).whereType<StoryElement>().toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded.map(parseElement).whereType<StoryElement>().toList();
          }
          final single = parseElement(decoded);
          if (single != null) {
            return [single];
          }
        } catch (_) {
          return const [];
        }
      }
      return null;
    }

    final parsedInteractiveElements =
        parseElements(map['interactive_elements']);

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
      viewerCanReply: map['viewer_can_reply'] == true,
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
      interactiveElements: parsedInteractiveElements,
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

@immutable
class StoryPollOptionResult {
  final int optionIndex;
  final String text;
  final int votes;
  final double percentage;

  const StoryPollOptionResult({
    required this.optionIndex,
    required this.text,
    required this.votes,
    required this.percentage,
  });

  StoryPollOptionResult copyWith({
    int? optionIndex,
    String? text,
    int? votes,
    double? percentage,
  }) {
    return StoryPollOptionResult(
      optionIndex: optionIndex ?? this.optionIndex,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      percentage: percentage ?? this.percentage,
    );
  }

  factory StoryPollOptionResult.fromMap(Map<String, dynamic> map) {
    return StoryPollOptionResult(
      optionIndex: (map['option_index'] as num?)?.toInt() ?? 0,
      text: (map['text'] ?? '').toString(),
      votes: (map['votes'] as num?)?.toInt() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class StoryPollResult {
  final String storyId;
  final String elementId;
  final String question;
  final int totalVotes;
  final int? userOptionIndex;
  final List<StoryPollOptionResult> options;

  const StoryPollResult({
    required this.storyId,
    required this.elementId,
    required this.question,
    required this.totalVotes,
    required this.userOptionIndex,
    required this.options,
  });

  bool get hasVoted => userOptionIndex != null;

  StoryPollResult copyWith({
    String? storyId,
    String? elementId,
    String? question,
    int? totalVotes,
    int? userOptionIndex,
    List<StoryPollOptionResult>? options,
  }) {
    return StoryPollResult(
      storyId: storyId ?? this.storyId,
      elementId: elementId ?? this.elementId,
      question: question ?? this.question,
      totalVotes: totalVotes ?? this.totalVotes,
      userOptionIndex: userOptionIndex ?? this.userOptionIndex,
      options: options ?? this.options,
    );
  }

  factory StoryPollResult.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['options'] as List?) ?? const [];
    return StoryPollResult(
      storyId: (map['story_id'] ?? '').toString(),
      elementId: (map['element_id'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      totalVotes: (map['total_votes'] as num?)?.toInt() ?? 0,
      userOptionIndex: (map['user_option_index'] as num?)?.toInt(),
      options: rawOptions
          .map((item) {
            if (item is Map<String, dynamic>) {
              return StoryPollOptionResult.fromMap(item);
            }
            if (item is Map) {
              return StoryPollOptionResult.fromMap(
                item.map((key, value) => MapEntry(key.toString(), value)),
              );
            }
            return null;
          })
          .whereType<StoryPollOptionResult>()
          .toList(),
    );
  }
}

@immutable
class StoryQuestionAnswer {
  final String id;
  final String storyId;
  final String elementId;
  final String respondentId;
  final String respondentUsername;
  final String? respondentAvatarUrl;
  final String answer;
  final DateTime createdAt;

  const StoryQuestionAnswer({
    required this.id,
    required this.storyId,
    required this.elementId,
    required this.respondentId,
    required this.respondentUsername,
    required this.respondentAvatarUrl,
    required this.answer,
    required this.createdAt,
  });

  factory StoryQuestionAnswer.fromMap(Map<String, dynamic> map) {
    return StoryQuestionAnswer(
      id: (map['id'] ?? '').toString(),
      storyId: (map['story_id'] ?? '').toString(),
      elementId: (map['element_id'] ?? '').toString(),
      respondentId: (map['respondent_id'] ?? '').toString(),
      respondentUsername: (map['respondent_username'] ?? '').toString(),
      respondentAvatarUrl: map['respondent_avatar_url']?.toString(),
      answer: (map['answer'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
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
