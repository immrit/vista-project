import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../utils/verification_badge_utils.dart';

// Enum برای نوع تایید
enum VerificationType {
  none, // بدون نشان
  blueTick, // نشان آبی
  goldTick, // نشان طلایی
  blackTick // نشان مشکی
}

@immutable
class UserModel extends Equatable {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? email;
  final String? role;
  final DateTime? createdAt;
  final bool isVerified;
  final VerificationType verificationType; // اضافه کردن verificationType

  const UserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.email,
    this.role,
    this.createdAt,
    this.isVerified = false,
    this.verificationType = VerificationType.none, // مقدار پیش‌فرض none
  });

  // سازنده از JSON
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  // سازنده از Map با هندلینگ پیشرفته
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final isVerified = map['is_verified'] as bool? ?? false;
    final resolvedType = resolveVerificationBadgeType(
      isVerified: isVerified,
      verificationType: map['verification_type'],
      role: map['role']?.toString(),
    );

    return UserModel(
      id: (map['user_id'] ?? map['id'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      avatarUrl: map['avatar_url']?.toString(),
      email: map['email']?.toString(),
      role: map['role']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      isVerified: isVerified,
      verificationType: _mapResolvedType(resolvedType),
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

  // تبدیل به Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'avatar_url': avatarUrl,
        'email': email,
        'role': role,
        'created_at': createdAt?.toIso8601String(),
        'is_verified': isVerified,
        'verification_type':
            verificationType.name, // اضافه کردن verification_type
      };

  // تبدیل به JSON
  String toJson() => json.encode(toMap());

  // متد copyWith برای تغییرات ایمن
  UserModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? email,
    String? role,
    DateTime? createdAt,
    bool? isVerified,
    VerificationType? verificationType, // اضافه کردن verificationType
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ??
          this.verificationType, // پیاده‌سازی verificationType
    );
  }

  // متد toString برای لاگ و دیباگ
  @override
  String toString() => '''
    Profile(
      id: $id, 
      username: $username, 
      email: $email,
      role: $role,
      isVerified: $isVerified,
      verificationType: $verificationType
    )''';

  // Equatable برای مقایسه‌های دقیق
  @override
  List<Object?> get props =>
      [id, username, avatarUrl, email, role, isVerified, verificationType];

  // متدهای اضافی برای بررسی وضعیت
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;
  bool get hasEmail => email != null && email!.isNotEmpty;
  bool get hasBlueBadge =>
      isVerified && verificationType == VerificationType.blueTick;
  bool get hasGoldBadge =>
      isVerified && verificationType == VerificationType.goldTick;
  bool get hasBlackBadge =>
      isVerified && verificationType == VerificationType.blackTick;
  bool get hasAnyBadge =>
      isVerified && verificationType != VerificationType.none;
  bool get isPremiumUser => role == 'premium';
  bool get hasUnlimitedPrivileges => hasBlueBadge;
  bool get hasPremiumPrivileges =>
      hasUnlimitedPrivileges || hasGoldBadge || hasBlackBadge || isPremiumUser;
}
