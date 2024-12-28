import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class PublicPostModel extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String content;
  final DateTime createdAt;
  final String username;
  final String avatarUrl;
  int likeCount;
  bool isLiked;
  final bool isVerified;
  int commentCount; // جدید: اضافه کردن فیلد تعداد کامنت‌ها

  PublicPostModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.content,
    required this.createdAt,
    required this.username,
    this.avatarUrl = '',
    this.likeCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.commentCount = 0, // مقدار پیش‌فرض
  });

  // متد سازنده از Map با روش‌های پیشرفته‌تر
  factory PublicPostModel.fromMap(Map<String, dynamic> map) {
    return PublicPostModel(
      id: _parseString(map, 'id'),
      userId: _parseString(map, 'user_id'),
      fullName: _parseString(map, 'full_name'),
      content: _parseString(map, 'content'),
      createdAt: _parseDateTime(map, 'created_at'),
      username: _parseUsername(map),
      avatarUrl: _parseAvatarUrl(map),
      likeCount: _parseInt(map, 'like_count'),
      isLiked: _parseBool(map, 'is_liked'),
      isVerified: _parseVerified(map),
      commentCount: map['comment_count'] as int? ?? 0, // مقدار پیش‌فرض
// جدید: افزودن پارسینگ تعداد کامنت
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

  // متد تبدیل به Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'profiles': {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
      },
      'like_count': likeCount,
      'is_liked': isLiked,
      'comment_count': commentCount, // جدید: اضافه کردن تعداد کامنت‌ها به Map
    };
  }

  // متد تبدیل به JSON
  String toJson() => json.encode(toMap());

  // متد سازنده از JSON
  factory PublicPostModel.fromJson(String source) =>
      PublicPostModel.fromMap(json.decode(source));

  // متد copyWith برای تغییر خصوصیات
  PublicPostModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? content,
    DateTime? createdAt,
    String? username,
    String? avatarUrl,
    int? likeCount,
    bool? isLiked,
    bool? isVerified,
    int? commentCount, // جدید: افزودن تعداد کامنت‌ها به copyWith
  }) {
    return PublicPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified ?? this.isVerified,
      commentCount: commentCount ?? this.commentCount, // جدید
    );
  }

  // override کردن متد toString برای چاپ راحت‌تر
  @override
  String toString() {
    return '''
    PublicPostModel(
      id: $id, 
      userId: $userId, 
      fullName: $fullName, 
      content: $content, 
      createdAt: $createdAt, 
      username: $username, 
      avatarUrl: $avatarUrl, 
      likeCount: $likeCount, 
      isLiked: $isLiked, 
      isVerified: $isVerified, 
      commentCount: $commentCount // جدید
    )''';
  }

  // implementation of Equatable
  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        content,
        createdAt,
        username,
        avatarUrl,
        likeCount,
        isLiked,
        isVerified,
        commentCount, // جدید
      ];
}
