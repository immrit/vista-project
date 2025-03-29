import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../view/screen/Stories/story_system.dart';
import 'publicPostModel.dart';

enum VerificationType {
  none, // بدون نشان
  blueTick, // نشان آبی (مدیران و ناظران)
  goldTick, // نشان طلایی (حساب تجاری)
  blackTick // نشان مشکی (تولیدکنندگان محتوا)
}

@immutable
class ProfileModel extends Equatable {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? email;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final DateTime? createdAt;
  final bool isVerified;
  final VerificationType verificationType;
  final bool isFollowed;
  final List<PublicPostModel> posts;
  final List<Story> stories; // اضافه کردن لیست استوری‌ها

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.email,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.createdAt,
    this.isVerified = false,
    this.verificationType = VerificationType.none,
    this.isFollowed = false,
    this.posts = const [],
    this.stories = const [], // مقدار پیش‌فرض برای استوری‌ها
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    if (map['id'] == null || map['username'] == null) {
      throw ArgumentError('Missing required fields: id or username');
    }

    return ProfileModel(
      id: map['id'].toString(),
      username: map['username'].toString(),
      fullName: map['full_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      email: map['email']?.toString(),
      bio: map['bio']?.toString(),
      followersCount: map['followers_count'] ?? 0,
      followingCount: map['following_count'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      isVerified: map['is_verified'] ?? false,
      verificationType: VerificationType.values.firstWhere(
        (type) => type.name == map['verification_type'],
        orElse: () => VerificationType.none,
      ),
      isFollowed: map['is_followed'] ?? false,
      posts: (map['posts'] as List<dynamic>? ?? [])
          .map((post) => PublicPostModel.fromMap(post))
          .toList(),
      stories: (map['stories'] as List<dynamic>? ?? [])
          .map((story) => Story.fromMap(story))
          .toList(), // واکشی استوری‌ها
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
      'bio': bio,
      'followers_count': followersCount,
      'following_count': followingCount,
      'created_at': createdAt?.toIso8601String(),
      'is_verified': isVerified,
      'verification_type': verificationType.name,
      'is_followed': isFollowed,
      'posts': posts.map((post) => post.toMap()).toList(),
      'stories':
          stories.map((story) => story.toMap()).toList(), // ذخیره استوری‌ها
    };
  }

  String toJson() => json.encode(toMap());

  ProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? email,
    String? bio,
    int? followersCount,
    int? followingCount,
    DateTime? createdAt,
    bool? isVerified,
    VerificationType? verificationType,
    bool? isFollowed,
    List<PublicPostModel>? posts,
    List<Story>? stories, // اضافه کردن استوری‌ها به copyWith
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      isFollowed: isFollowed ?? this.isFollowed,
      posts: posts ?? this.posts,
      stories: stories ?? this.stories, // اضافه کردن استوری‌ها
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        fullName,
        avatarUrl,
        email,
        bio,
        followersCount,
        followingCount,
        createdAt,
        isVerified,
        verificationType,
        isFollowed,
        posts,
        stories, // اضافه کردن استوری‌ها به props
      ];
  bool get hasBlueBadge =>
      isVerified && verificationType == VerificationType.blueTick;
  bool get hasGoldBadge =>
      isVerified && verificationType == VerificationType.goldTick;
  bool get hasBlackBadge =>
      isVerified && verificationType == VerificationType.blackTick;
  bool get hasAnyBadge =>
      isVerified && verificationType != VerificationType.none;
}
