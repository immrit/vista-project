import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// مدل وضعیت پروفایل (مشابه Note در ویستا)
/// هر کاربر می‌تواند یک وضعیت ۲۴ ساعته داشته باشد
@immutable
class ProfileNoteModel extends Equatable {
  /// شناسه یکتای وضعیت
  final String id;

  /// شناسه کاربر صاحب وضعیت
  final String userId;

  /// متن وضعیت (حداکثر ۶۰ کاراکتر)
  final String content;

  /// زمان ایجاد وضعیت
  final DateTime createdAt;

  /// زمان انقضای وضعیت (۲۴ ساعت پس از ایجاد)
  final DateTime expiresAt;

  const ProfileNoteModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.expiresAt,
  });

  /// آیا وضعیت منقضی شده است؟
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// زمان باقی‌مانده تا انقضا
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  /// درصد زمان باقی‌مانده (برای نمایش پیشرفت)
  double get remainingPercentage {
    final totalDuration = expiresAt.difference(createdAt);
    final remaining = remainingTime;
    if (totalDuration.inSeconds == 0) return 0;
    return remaining.inSeconds / totalDuration.inSeconds;
  }

  /// ساخت از JSON دیتابیس
  factory ProfileNoteModel.fromJson(Map<String, dynamic> json) {
    return ProfileNoteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// تبدیل به JSON برای ذخیره
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  /// کپی با تغییرات
  ProfileNoteModel copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return ProfileNoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, content, createdAt, expiresAt];

  @override
  String toString() {
    return 'ProfileNoteModel(id: $id, userId: $userId, content: $content, '
        'createdAt: $createdAt, expiresAt: $expiresAt, isExpired: $isExpired)';
  }
}
