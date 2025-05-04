import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'ProfileModel.dart'; // واردکردن ProfileModel برای استفاده از VerificationType

@immutable
class PublicPostModel extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String content;
  final String? imageUrl;
  final String? videoUrl; // افزودن فیلد videoUrl برای ویدیوها
  final DateTime createdAt;
  final String username;
  final String avatarUrl;
  final List<String> hashtags;
  int likeCount;
  bool isLiked;
  final bool isVerified;
  final VerificationType verificationType;
  int commentCount;
  final String? musicUrl;
  final String? title;

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
    this.likeCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.verificationType = VerificationType.none,
    this.commentCount = 0,
    List<String>? hashtags,
    this.musicUrl,
    this.title,
  }) : hashtags = hashtags ?? _extractHashtags(content);

  // متد استاتیک برای استخراج هشتگ‌ها از متن
  static List<String> _extractHashtags(String text) {
    final hashtagRegExp = RegExp(r'#\w+');
    return hashtagRegExp
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }

  // متد سازنده از Map
  factory PublicPostModel.fromMap(Map<String, dynamic> map) {
    print("Music URL from API: ${map['music_url']}");
    print("Video URL from API: ${map['video_url']}"); // لاگ برای دیباگ ویدیو

    return PublicPostModel(
      id: _parseString(map, 'id'),
      userId: _parseString(map, 'user_id'),
      fullName: _parseString(map, 'full_name'),
      content: _parseString(map, 'content'),
      imageUrl: _parseString(map, 'image_url', defaultValue: ""),
      videoUrl: _parseString(map, 'video_url',
          defaultValue: ""), // پارس کردن video_url
      createdAt: _parseDateTime(map, 'created_at'),
      username: _parseUsername(map),
      avatarUrl: _parseAvatarUrl(map),
      likeCount: _parseInt(map, 'like_count'),
      isLiked: _parseBool(map, 'is_liked'),
      isVerified: map['is_verified'] ?? false,
      verificationType:
          _parseVerificationType(map), // <-- فقط همین خط تغییر کند
      commentCount: _parseInt(map, 'comment_count'),
      hashtags: _parseHashtags(map),
      musicUrl: _parseString(map, 'music_url', defaultValue: ""),
      title: _parseString(map, 'title'),
    );
  }

  // متدهای کمکی برای parse کردن
  static String _parseString(Map<String, dynamic> map, String key,
      {String defaultValue = ''}) {
    return map[key]?.toString() ?? defaultValue;
  }

  static int _parseInt(Map<String, dynamic> map, String key,
      {int defaultValue = 0}) {
    return (map[key] is num) ? (map[key] as num).toInt() : defaultValue;
  }

  static bool _parseBool(Map<String, dynamic> map, String key,
      {bool defaultValue = false}) {
    if (map[key] is bool) return map[key] as bool;
    return defaultValue;
  }

  static DateTime _parseDateTime(Map<String, dynamic> map, String key) {
    try {
      return DateTime.parse(
          map[key]?.toString() ?? DateTime.now().toIso8601String());
    } catch (e) {
      return DateTime.now();
    }
  }

  static String _parseUsername(Map<String, dynamic> map) {
    return map['profiles']?['username']?.toString() ?? 'نام کاربری ناشناخته';
  }

  static String _parseFullName(Map<String, dynamic> map) {
    return map['profiles']?['full_name']?.toString() ?? 'نام کاربری ناشناخته';
  }

  static String _parseAvatarUrl(Map<String, dynamic> map) {
    return map['profiles']?['avatar_url']?.toString() ?? '';
  }

  static bool _parseVerified(Map<String, dynamic> map) {
    return map['profiles']?['is_verified'] ?? false;
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
    if (map['hashtags'] != null) {
      return List<String>.from(map['hashtags']);
    }
    return _extractHashtags(_parseString(map, 'content'));
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
      'profiles': {
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
      'music_url': musicUrl,
      'title': title,
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
    int? likeCount,
    bool? isLiked,
    bool? isVerified,
    VerificationType? verificationType,
    int? commentCount,
    List<String>? hashtags,
    String? musicUrl,
    String? title,
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
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      commentCount: commentCount ?? this.commentCount,
      hashtags: hashtags ?? this.hashtags,
      musicUrl: musicUrl ?? this.musicUrl,
      title: title ?? this.title,
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
    )''';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        content,
        imageUrl,
        videoUrl, // افزودن ویدیو به props
        createdAt,
        username,
        avatarUrl,
        likeCount,
        isLiked,
        isVerified,
        verificationType,
        commentCount,
        hashtags,
        musicUrl,
        title,
      ];

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
