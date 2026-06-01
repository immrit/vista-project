import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../utils/verification_badge_utils.dart';

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
  final String? websiteUrl;
  final String? location;
  final int followersCount;
  final int followingCount;
  final DateTime? createdAt;
  final DateTime? emailVerifiedAt;
  final bool isVerified;
  final VerificationType verificationType;
  final bool isFollowed;
  final bool isPrivate;
  final List<PublicPostModel> posts;
  // استوری‌ها اکنون از Provider جداگانه (activeStoriesProvider) می‌آیند
  final String? role; // فیلد نقش کاربر
  final int postsCount;
  final String? publicKey; // کلید عمومی برای E2EE
  final int? joinOrder; // ترتیب ثبت‌نام در ویستا
  final String? phoneNumber;
  final String? birthDate;
  final String? gender;
  final String? maritalStatus;
  final bool showEmail;
  final bool showBirthDate;
  final bool showGender;
  final bool showMaritalStatus;
  final int usernameChangesCount;
  final String? registrationCountry;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.email,
    this.bio,
    this.websiteUrl,
    this.location,
    this.followersCount = 0,
    this.followingCount = 0,
    this.createdAt,
    this.emailVerifiedAt,
    this.isVerified = false,
    this.verificationType = VerificationType.none,
    this.isFollowed = false,
    this.isPrivate = false,
    this.posts = const [],
    this.role,
    this.postsCount = 0,
    this.publicKey,
    this.joinOrder,
    this.phoneNumber,
    this.birthDate,
    this.gender,
    this.maritalStatus,
    this.showEmail = false,
    this.showBirthDate = false,
    this.showGender = false,
    this.showMaritalStatus = false,
    this.usernameChangesCount = 0,
    this.registrationCountry,
  });

  static String _trimmed(dynamic value) => value?.toString().trim() ?? '';

  static String _firstNonEmpty(
    Iterable<dynamic> values, {
    required String fallback,
  }) {
    for (final value in values) {
      final trimmed = _trimmed(value);
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  static bool _boolValue(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final id = _firstNonEmpty([map['id'], map['user_id']], fallback: '');
    final username = _firstNonEmpty(
      [map['username'], map['full_name']],
      fallback: 'user',
    );
    if (id.isEmpty) {
      throw ArgumentError('Missing required fields: id/user_id or username');
    }

    final isVerified = map['is_verified'] as bool? ?? false;
    final role = map['role']?.toString();
    final parsedType = resolveVerificationBadgeType(
      isVerified: isVerified,
      verificationType: map['verification_type'],
      role: role,
    );

    return ProfileModel(
      id: id,
      username: username,
      fullName: map['full_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      email: map['email']?.toString(),
      bio: map['bio']?.toString(),
      websiteUrl: map['website_url']?.toString(),
      location: map['location']?.toString(),
      followersCount: map['followers_count'] ?? map['follower_count'] ?? 0,
      followingCount: map['following_count'] ?? map['following_count'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      emailVerifiedAt: map['email_verified_at'] != null
          ? DateTime.tryParse(map['email_verified_at'].toString())
          : map['email_confirmed_at'] != null
              ? DateTime.tryParse(map['email_confirmed_at'].toString())
              : null,
      isVerified: isVerified,
      verificationType: _mapResolvedType(parsedType),
      isFollowed: map['is_followed'] ?? false,
      isPrivate: map['is_private'] ?? false,
      posts: (map['posts'] as List<dynamic>? ?? [])
          .map((post) => PublicPostModel.fromMap(post))
          .toList(),
      role: role,
      postsCount: map['posts_count'] ?? map['post_count'] ?? 0,
      publicKey: map['public_key']?.toString(),
      joinOrder: map['join_order'] != null
          ? int.tryParse(map['join_order'].toString())
          : null,
      phoneNumber: map['phone_number']?.toString(),
      birthDate: map['birth_date']?.toString(),
      gender: map['gender']?.toString(),
      maritalStatus: map['marital_status']?.toString(),
      showEmail: _boolValue(map['show_email']),
      showBirthDate: _boolValue(map['show_birth_date']),
      showGender: _boolValue(map['show_gender']),
      showMaritalStatus: _boolValue(map['show_marital_status']),
      usernameChangesCount:
          int.tryParse((map['username_changes_count'] ?? 0).toString()) ?? 0,
      registrationCountry: map['registration_country']?.toString(),
    );
  }

  static VerificationType _mapResolvedType(ResolvedVerificationBadgeType type) {
    switch (type) {
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
      'bio': bio,
      'website_url': websiteUrl,
      'location': location,
      'followers_count': followersCount,
      'following_count': followingCount,
      'created_at': createdAt?.toIso8601String(),
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'is_verified': isVerified,
      'verification_type': verificationType.name,
      'is_followed': isFollowed,
      'is_private': isPrivate,
      'posts': posts.map((post) => post.toMap()).toList(),
      'role': role,
      'posts_count': postsCount,
      'public_key': publicKey,
      'join_order': joinOrder,
      'phone_number': phoneNumber,
      'birth_date': birthDate,
      'gender': gender,
      'marital_status': maritalStatus,
      'show_email': showEmail,
      'show_birth_date': showBirthDate,
      'show_gender': showGender,
      'show_marital_status': showMaritalStatus,
      'username_changes_count': usernameChangesCount,
      'registration_country': registrationCountry,
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
    String? websiteUrl,
    String? location,
    int? followersCount,
    int? followingCount,
    DateTime? createdAt,
    DateTime? emailVerifiedAt,
    bool? isVerified,
    VerificationType? verificationType,
    bool? isFollowed,
    bool? isPrivate,
    List<PublicPostModel>? posts,
    String? role,
    int? postsCount,
    String? publicKey,
    int? joinOrder,
    String? phoneNumber,
    String? birthDate,
    String? gender,
    String? maritalStatus,
    bool? showEmail,
    bool? showBirthDate,
    bool? showGender,
    bool? showMaritalStatus,
    int? usernameChangesCount,
    String? registrationCountry,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      location: location ?? this.location,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt ?? this.createdAt,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      isFollowed: isFollowed ?? this.isFollowed,
      isPrivate: isPrivate ?? this.isPrivate,
      posts: posts ?? this.posts,
      role: role ?? this.role,
      postsCount: postsCount ?? this.postsCount,
      publicKey: publicKey ?? this.publicKey,
      joinOrder: joinOrder ?? this.joinOrder,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      showEmail: showEmail ?? this.showEmail,
      showBirthDate: showBirthDate ?? this.showBirthDate,
      showGender: showGender ?? this.showGender,
      showMaritalStatus: showMaritalStatus ?? this.showMaritalStatus,
      usernameChangesCount: usernameChangesCount ?? this.usernameChangesCount,
      registrationCountry: registrationCountry ?? this.registrationCountry,
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
        websiteUrl,
        location,
        followersCount,
        followingCount,
        createdAt,
        emailVerifiedAt,
        isVerified,
        verificationType,
        isFollowed,
        isPrivate,
        posts,
        role,
        postsCount,
        publicKey,
        joinOrder,
        phoneNumber,
        birthDate,
        gender,
        maritalStatus,
        showEmail,
        showBirthDate,
        showGender,
        showMaritalStatus,
        usernameChangesCount,
        registrationCountry,
      ];
  bool get hasBlueBadge =>
      isVerified && verificationType == VerificationType.blueTick;
  bool get hasGoldBadge =>
      isVerified && verificationType == VerificationType.goldTick;
  bool get hasBlackBadge =>
      isVerified && verificationType == VerificationType.blackTick;
  bool get hasAnyBadge =>
      isVerified && verificationType != VerificationType.none;

  // متدهای کمکی برای بررسی نقش کاربر
  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
  bool get isAdminOrModerator => role == 'admin' || role == 'moderator';
  bool get isNormalUser => role == 'normal' || role == null;
  bool get isPremiumUser => role == 'premium';
}
