import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class PublicPostModel extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final String username;
  final String avatarUrl;
  final List<String> hashtags;
  int likeCount;
  bool isLiked;
  final bool isVerified;
  int commentCount;
  final String? musicUrl;
  final String? title; // اضافه کردن فیلد title

  PublicPostModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.username,
    this.avatarUrl = '',
    this.likeCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.commentCount = 0,
    List<String>? hashtags,
    this.musicUrl,
    this.title, // اضافه کردن title به constructor
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
    print(
        "Music URL from API: ${map['music_url']}"); // اضافه کردن این خط برای دیباگ
    return PublicPostModel(
      id: _parseString(map, 'id'),
      userId: _parseString(map, 'user_id'),
      fullName: _parseString(map, 'full_name'),
      content: _parseString(map, 'content'),
      imageUrl: _parseString(map, 'image_url', defaultValue: ""),
      createdAt: _parseDateTime(map, 'created_at'),
      username: _parseUsername(map),
      avatarUrl: _parseAvatarUrl(map),
      likeCount: _parseInt(map, 'like_count'),
      isLiked: _parseBool(map, 'is_liked'),
      isVerified: _parseVerified(map),
      commentCount: _parseInt(map, 'comment_count'),
      hashtags: _parseHashtags(map),
      musicUrl: _parseString(map, 'music_url', defaultValue: ""),
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
      'created_at': createdAt.toIso8601String(),
      'profiles': {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
      },
      'like_count': likeCount,
      'is_liked': isLiked,
      'comment_count': commentCount,
      'hashtags': hashtags,
      'music_url': musicUrl,
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
    DateTime? createdAt,
    String? username,
    String? avatarUrl,
    int? likeCount,
    bool? isLiked,
    bool? isVerified,
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
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified ?? this.isVerified,
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
      createdAt: $createdAt, 
      username: $username, 
      avatarUrl: $avatarUrl, 
      likeCount: $likeCount, 
      isLiked: $isLiked, 
      isVerified: $isVerified, 
      commentCount: $commentCount,
      hashtags: $hashtags,
      musicUrl: $musicUrl,
    )''';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        content,
        imageUrl,
        createdAt,
        username,
        avatarUrl,
        likeCount,
        isLiked,
        isVerified,
        commentCount,
        hashtags,
        musicUrl,
        title,
      ];
}
