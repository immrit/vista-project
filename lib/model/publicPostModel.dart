import 'dart:convert';
// Equatable removed: model is mutable in this codebase
import 'ProfileModel.dart'; // واردکردن ProfileModel برای استفاده از VerificationType
import '../utils/verification_badge_utils.dart';
import '../utils/env_config.dart';

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
  final bool hideLikeCount;
  final bool hideCommentCount;
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
  final bool editedByVista;

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
    this.hideLikeCount = false,
    this.hideCommentCount = false,
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
    this.editedByVista = false,
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
      userId: _parseUserId(map),
      fullName: _parseFullName(map),
      content: _parseString(map, 'content') ?? '',
      imageUrl: _parseMediaUrl(map, 'image_url'),
      videoUrl: _parseMediaUrl(map, 'video_url'), 
      createdAt: _parseDateTime(map, 'created_at') ?? DateTime.now(),
      username: _parseUsername(map),
      avatarUrl: _parseAvatarUrl(map),
      profiles: map['profiles'] as Map<String, dynamic>?,
      likeCount: _parseInt(map, 'like_count'),
      isLiked: _parseBool(map, 'is_liked'),
      hideLikeCount: _parseVisibilityFlag(
        map,
        primaryKey: 'hide_like_count',
        fallbackKeys: const ['is_like_count_hidden', 'hide_likes_count'],
      ),
      hideCommentCount: _parseVisibilityFlag(
        map,
        primaryKey: 'hide_comment_count',
        fallbackKeys: const ['is_comment_count_hidden', 'hide_comments_count'],
      ),
      isVerified: _parseIsVerified(map),
      verificationType:
          _parseVerificationType(map), // <-- فقط همین خط تغییر کند
      commentCount: _parseInt(map, 'comment_count'),
      hashtags: _parseHashtags(map),
      musicUrl: _parseMediaUrl(map, 'music_url'),
      title: _parseString(map, 'title'),
      feedSource: _parseString(map, 'feed_source', defaultValue: null),
      feedScore: _parseDouble(map, 'feed_score', defaultValue: null),
      authorFollowStatus:
          _parseString(map, 'author_follow_status', defaultValue: 'unknown') ??
              'unknown',
      moderatorId: _nullableString(map, 'moderator_id'),
      moderatorUsername: _nullableString(map, 'moderator_username'),
      moderatedAt: _parseDateTime(map, 'moderated_at'),
      moderationReason: _nullableString(map, 'moderation_reason'),
      editedByVista: _parseBool(map, 'edited_by_vista'),
    );
  }

  static String? _parseMediaUrl(Map<String, dynamic> map, String key) {
    final raw = _parseString(map, key, defaultValue: null);
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    final baseUrl = EnvConfig.apiBaseUrl.replaceFirst('api.', 's3.');
    final cleanPath = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$baseUrl/$cleanPath';
  }

  // متدهای کمکی برای parse کردن
  static String? _nullableString(Map<String, dynamic> map, String key) {
    final value = _parseString(map, key, defaultValue: null);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? _parseString(Map<String, dynamic> map, String key,
      {String? defaultValue = ''}) {
    final value = map[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is List) {
      if (value.isEmpty) return defaultValue;
      final result = value.first?.toString();
      return result?.isEmpty == true ? defaultValue : result;
    }
    final result = value.toString();
    if (result.startsWith('[') && result.endsWith(']')) {
      try {
        final List parsed = json.decode(result);
        if (parsed.isNotEmpty) {
          final str = parsed.first?.toString();
          return str?.isEmpty == true ? defaultValue : str;
        }
      } catch (_) {}
    }
    if (result.startsWith('{') && result.endsWith('}')) {
      final inner = result.substring(1, result.length - 1);
      final parts = inner.split(',');
      if (parts.isNotEmpty) return parts.first.trim();
    }
    return result.isEmpty ? defaultValue : result;
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

  static bool _parseVisibilityFlag(
    Map<String, dynamic> map, {
    required String primaryKey,
    List<String> fallbackKeys = const [],
  }) {
    final keys = <String>[primaryKey, ...fallbackKeys];
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final raw = map[key];
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = raw?.toString().trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }
    return false;
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
    final author = _authorMap(map);
    final candidates = [
      map['profiles']?['username']?.toString(),
      author?['username']?.toString(),
      map['username']?.toString(),
    ];
    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return 'نام کاربری ناشناخته';
  }

  static String _parseAvatarUrl(Map<String, dynamic> map) {
    final author = _authorMap(map);
    final candidates = [
      map['profiles']?['avatar_url']?.toString(),
      author?['avatar_url']?.toString(),
      map['avatar_url']?.toString(),
    ];
    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return _normalizeAvatarUrl(trimmed);
      }
    }
    return '';
  }

  static Map<String, dynamic>? _authorMap(Map<String, dynamic> map) {
    final author = map['author'];
    if (author is Map<String, dynamic>) return author;
    if (author is Map) return author.cast<String, dynamic>();
    return null;
  }

  static String _parseUserId(Map<String, dynamic> map) {
    final author = _authorMap(map);
    final candidates = [
      author?['id']?.toString(),
      map['user_id']?.toString(),
      map['profiles']?['id']?.toString(),
    ];
    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _parseFullName(Map<String, dynamic> map) {
    final author = _authorMap(map);
    final candidates = [
      author?['full_name']?.toString(),
      map['profiles']?['full_name']?.toString(),
      map['full_name']?.toString(),
    ];
    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _normalizeAvatarUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final baseUrl = EnvConfig.apiBaseUrl.replaceFirst('api.', 's3.');
    final cleanPath = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$baseUrl/$cleanPath';
  }

  static VerificationType _parseVerificationType(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? const {};
    final isVerified = _parseIsVerified(map);
    final role = (map['role'] ?? profile['role'])?.toString();
    final dynamic raw =
        map['verification_type'] ?? profile['verification_type'];

    final resolved = resolveVerificationBadgeType(
      isVerified: isVerified,
      verificationType: raw,
      role: role,
    );
    switch (resolved) {
      case ResolvedVerificationBadgeType.blueTick:
        return VerificationType.blueTick;
      case ResolvedVerificationBadgeType.goldTick:
        return VerificationType.goldTick;
      case ResolvedVerificationBadgeType.blackTick:
        return VerificationType.blackTick;
      case ResolvedVerificationBadgeType.none:
        return VerificationType.none;
    }
  }

  static bool _parseIsVerified(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>? ?? const {};
    final direct = _coerceBool(map['is_verified']);
    final fromProfile = _coerceBool(profile['is_verified']);
    final rawType = map['verification_type'] ?? profile['verification_type'];
    final hasBadgeType = parseVerificationBadgeType(rawType) !=
        ResolvedVerificationBadgeType.none;
    return direct || fromProfile || hasBadgeType;
  }

  static bool _coerceBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
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
      'hide_like_count': hideLikeCount,
      'hide_comment_count': hideCommentCount,
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
      'edited_by_vista': editedByVista,
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
    bool? hideLikeCount,
    bool? hideCommentCount,
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
    bool? editedByVista,
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
      hideLikeCount: hideLikeCount ?? this.hideLikeCount,
      hideCommentCount: hideCommentCount ?? this.hideCommentCount,
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
      editedByVista: editedByVista ?? this.editedByVista,
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
      hideLikeCount: $hideLikeCount,
      hideCommentCount: $hideCommentCount,
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
