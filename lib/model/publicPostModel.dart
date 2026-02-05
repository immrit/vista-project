import 'dart:convert';
// Equatable removed: model is mutable in this codebase
import 'ProfileModel.dart'; // واردکردن ProfileModel برای استفاده از VerificationType

class PublicPostModel {
  final String id;
  final String userId;
  final String fullName;
  final String content;
  final String? imageUrl;
  final String? videoUrl; // افزودن فیلد videoUrl برای ویدیوها
  final DateTime createdAt;
  final String username;
  final String avatarUrl;
  final Map<String, dynamic>? profiles; // افزودن فیلد profiles
  final List<String> hashtags;

  // Personalized feed diagnostics (optional; present when Node feed is used)
  final String? feedSource; // personal | following | trending | own | fallback
  final double? feedScore; // returned only when debug=true
  final String authorFollowStatus; // following | requested | none | unknown

  int likeCount;
  bool isLiked;
  final bool isVerified;
  final VerificationType verificationType;
  int commentCount;
  final String? musicUrl;
  final String? title;
  // فیلدهای مربوط به ناظر
  final String? moderatorId;
  final String? moderatorUsername;
  final DateTime? moderatedAt;
  final String? moderationReason;

  PublicPostModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.content,
    this.imageUrl,
    this.videoUrl, // افزودن پارامتر videoUrl
    required this.createdAt,
    required this.username,
    this.avatarUrl = '',
    this.profiles, // افزودن پارامتر profiles
    this.likeCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.verificationType = VerificationType.none,
    this.commentCount = 0,
    List<String>? hashtags,
    this.musicUrl,
    this.title,
    this.feedSource,
    this.feedScore,
    this.authorFollowStatus = 'unknown',
    // پارامترهای مربوط به ناظر
    this.moderatorId,
    this.moderatorUsername,
    this.moderatedAt,
    this.moderationReason,
  }) : hashtags = hashtags ?? _extractHashtags(content);

  // متد استاتیک برای استخراج هشتگ‌ها از متن
  static List<String> _extractHashtags(String text) {
    // Keep tags without leading '#'
    final hashtagRegExp = RegExp(r'#([\\p{L}\\p{N}_]+)', unicode: true);
    return _normalizeTagList(
      hashtagRegExp.allMatches(text).map((m) => m.group(1)),
    );
  }

  // متد سازنده از Map
  factory PublicPostModel.fromMap(Map<String, dynamic> map) {
    return PublicPostModel(
      id: _parseString(map, 'id') ?? '',
      userId: _parseString(map, 'user_id') ?? '',
      fullName: _parseString(map, 'full_name') ?? '',
      content: _parseString(map, 'content') ?? '',
      imageUrl: _parseString(map, 'image_url', defaultValue: null),
      videoUrl: _parseString(map, 'video_url',
          defaultValue: null), // پارس کردن video_url
      createdAt: _parseDateTime(map, 'created_at') ?? DateTime.now(),
      username: _parseUsername(map),
      avatarUrl: _parseAvatarUrl(map),
      profiles: map['profiles'] as Map<String, dynamic>?,
      likeCount: _parseInt(map, 'like_count'),
      isLiked: _parseBool(map, 'is_liked'),
      isVerified: map['is_verified'] ?? false,
      verificationType:
          _parseVerificationType(map), // <-- فقط همین خط تغییر کند
      commentCount: _parseInt(map, 'comment_count'),
      hashtags: _parseHashtags(map),
      musicUrl: _parseString(map, 'music_url', defaultValue: null),
      title: _parseString(map, 'title'),
      feedSource: _parseString(map, 'feed_source', defaultValue: null),
      feedScore: _parseDouble(map, 'feed_score', defaultValue: null),
      authorFollowStatus:
          _parseString(map, 'author_follow_status', defaultValue: 'unknown') ??
              'unknown',
      moderatorId: _parseString(map, 'moderator_id'),
      moderatorUsername: _parseString(map, 'moderator_username'),
      moderatedAt: _parseDateTime(map, 'moderated_at'),
      moderationReason: _parseString(map, 'moderation_reason'),
    );
  }

  // متدهای کمکی برای parse کردن
  static String? _parseString(Map<String, dynamic> map, String key,
      {String? defaultValue = ''}) {
    if (map[key] == null) {
      return defaultValue;
    }
    final result = map[key]?.toString();
    return result?.isEmpty == true ? defaultValue : result;
  }

  static int _parseInt(Map<String, dynamic> map, String key,
      {int defaultValue = 0}) {
    return (map[key] is num) ? (map[key] as num).toInt() : defaultValue;
  }

  static double? _parseDouble(
    Map<String, dynamic> map,
    String key, {
    double? defaultValue,
  }) {
    final v = map[key];
    if (v == null) return defaultValue;
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return defaultValue;
    }
  }

  static bool _parseBool(Map<String, dynamic> map, String key,
      {bool defaultValue = false}) {
    if (map[key] is bool) return map[key] as bool;
    return defaultValue;
  }

  static DateTime? _parseDateTime(Map<String, dynamic> map, String key) {
    if (map[key] == null) return null;
    try {
      return DateTime.parse(map[key].toString());
    } catch (e) {
      return null;
    }
  }

  static String _parseUsername(Map<String, dynamic> map) {
    return map['profiles']?['username']?.toString() ?? 'نام کاربری ناشناخته';
  }

  static String _parseAvatarUrl(Map<String, dynamic> map) {
    return map['profiles']?['avatar_url']?.toString() ?? '';
  }

  static VerificationType _parseVerificationType(Map<String, dynamic> map) {
    final dynamic raw =
        map['verification_type'] ?? map['profiles']?['verification_type'];
    if (raw == null) return VerificationType.none;
    final String value = raw.toString();
    try {
      return VerificationType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => VerificationType.none,
      );
    } catch (_) {
      return VerificationType.none;
    }
  }

  static List<String> _parseHashtags(Map<String, dynamic> map) {
    // Preferred source: DB column `tags` (text[]).
    final tags = map['tags'];
    if (tags is List) {
      return _normalizeTagList(tags);
    }

    // Legacy/alternate source: `hashtags` (array-like).
    final hashtags = map['hashtags'];
    if (hashtags is List) {
      return _normalizeTagList(hashtags);
    }

    // Fallback: parse from content.
    return _extractHashtags(_parseString(map, 'content') ?? '');
  }

  static List<String> _normalizeTagList(Iterable<dynamic> raw) {
    final out = <String>[];
    final seen = <String>{};

    for (final item in raw) {
      if (item == null) continue;
      var s = item.toString().trim();
      if (s.isEmpty) continue;
      if (s.startsWith('#')) s = s.replaceFirst(RegExp(r'^#+'), '');
      s = s.trim();
      if (s.isEmpty) continue;
      final key = s.toLowerCase();
      if (seen.add(key)) out.add(s);
    }

    return out;
  }

  // متد تبدیل به Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      'video_url': videoUrl, // افزودن ویدیو به Map
      'created_at': createdAt.toIso8601String(),
      'profiles': profiles ??
          {
            'username': username,
            'full_name': fullName,
            'avatar_url': avatarUrl,
            'is_verified': isVerified,
            'verification_type': verificationType.name,
          },
      'like_count': likeCount,
      'is_liked': isLiked,
      'comment_count': commentCount,
      'hashtags': hashtags,
      'tags': hashtags,
      'music_url': musicUrl,
      'title': title,
      'feed_source': feedSource,
      'feed_score': feedScore,
      'author_follow_status': authorFollowStatus,
      'moderator_id': moderatorId,
      'moderator_username': moderatorUsername,
      'moderated_at': moderatedAt?.toIso8601String(),
      'moderation_reason': moderationReason,
    };
  }

  String toJson() => json.encode(toMap());

  factory PublicPostModel.fromJson(String source) =>
      PublicPostModel.fromMap(json.decode(source));

  PublicPostModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? content,
    String? imageUrl,
    String? videoUrl, // افزودن پارامتر videoUrl به copyWith
    DateTime? createdAt,
    String? username,
    String? avatarUrl,
    Map<String, dynamic>? profiles, // افزودن پارامتر profiles به copyWith
    int? likeCount,
    bool? isLiked,
    bool? isVerified,
    VerificationType? verificationType,
    int? commentCount,
    List<String>? hashtags,
    String? musicUrl,
    String? title,
    String? feedSource,
    double? feedScore,
    String? authorFollowStatus,
    // پارامترهای مربوط به ناظر
    String? moderatorId,
    String? moderatorUsername,
    DateTime? moderatedAt,
    String? moderationReason,
  }) {
    return PublicPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl, // افزودن ویدیو به copyWith
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profiles: profiles ?? this.profiles,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      commentCount: commentCount ?? this.commentCount,
      hashtags: hashtags ?? this.hashtags,
      musicUrl: musicUrl ?? this.musicUrl,
      title: title ?? this.title,
      feedSource: feedSource ?? this.feedSource,
      feedScore: feedScore ?? this.feedScore,
      authorFollowStatus: authorFollowStatus ?? this.authorFollowStatus,
      moderatorId: moderatorId ?? this.moderatorId,
      moderatorUsername: moderatorUsername ?? this.moderatorUsername,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      moderationReason: moderationReason ?? this.moderationReason,
    );
  }

  @override
  String toString() {
    return '''
    PublicPostModel(
      id: $id, 
      userId: $userId, 
      fullName: $fullName, 
      content: $content, 
      imageUrl: $imageUrl,
      videoUrl: $videoUrl, // افزودن ویدیو به toString
      createdAt: $createdAt, 
      username: $username, 
      avatarUrl: $avatarUrl, 
      likeCount: $likeCount, 
      isLiked: $isLiked, 
      isVerified: $isVerified, 
      verificationType: $verificationType,
      commentCount: $commentCount,
      hashtags: $hashtags,
      musicUrl: $musicUrl,
      title: $title,
      feedSource: $feedSource,
      feedScore: $feedScore,
      authorFollowStatus: $authorFollowStatus,
      moderatorId: $moderatorId,
      moderatorUsername: $moderatorUsername,
      moderatedAt: $moderatedAt,
      moderationReason: $moderationReason,
    )''';
  }

  // Note: equality/props from Equatable intentionally removed because
  // PublicPostModel instances are mutated in multiple places across the
  // codebase. If you need value equality later, consider providing a
  // comparator or reintroducing an immutable model.

  // متدهای کمکی
  bool get hasBlueBadge =>
      isVerified && verificationType == VerificationType.blueTick;
  bool get hasGoldBadge =>
      isVerified && verificationType == VerificationType.goldTick;
  bool get hasBlackBadge =>
      isVerified && verificationType == VerificationType.blackTick;
  bool get hasAnyBadge =>
      isVerified && verificationType != VerificationType.none;

  // متدهای کمکی برای تشخیص نوع پست
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasMusic => musicUrl != null && musicUrl!.isNotEmpty;
  bool get isTextOnly => !hasVideo && !hasImage && !hasMusic;
}
