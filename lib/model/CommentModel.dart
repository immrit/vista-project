import 'dart:convert';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String avatarUrl;
  bool isVerified;
  final String postOwnerId;
  final String? parentCommentId;
  List<CommentModel> replies;
  VerificationType verificationType; // اضافه کردن فیلد جدید نوع تیک

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.username,
    this.avatarUrl = '',
    this.isVerified = false,
    this.verificationType = VerificationType.none, // مقدار پیش‌فرض

    required this.postOwnerId,
    this.parentCommentId,
    this.replies = const [],
  });

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    DateTime? createdAt,
    String? username,
    String? avatarUrl,
    bool? isVerified,
    VerificationType? verificationType, // اضافه کردن به copyWith

    String? postOwnerId,
    String? parentCommentId,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      verificationType:
          verificationType ?? this.verificationType, // اضافه کردن به سازنده

      postOwnerId: postOwnerId ?? this.postOwnerId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
    );
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] as String? ?? '',
      postId: map['post_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      content: map['content'] as String? ?? 'متن خالی',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      username: map['profiles']?['username'] as String? ?? 'کاربر',
      avatarUrl: map['profiles']?['avatar_url'] as String? ?? '',
      isVerified: map['profiles']?['is_verified'] as bool? ?? false,
      verificationType: _mapVerificationType(
          map['profiles']?['verification_type']), // اضافه کردن دریافت نوع تیک
      postOwnerId:
          map['owner_id'] as String? ?? '', // Updated from 'post_owner_id'
      parentCommentId: map['parent_comment_id'] as String?, // Ensure nullable
      replies: (map['replies'] as List?)
              ?.map((replyMap) => CommentModel.fromMap(replyMap))
              .toList() ??
          [], // Ensure replies are mapped
    );
  }

  static VerificationType _mapVerificationType(dynamic value) {
    if (value == null) return VerificationType.none;
    if (value is String) {
      switch (value) {
        case 'blueTick':
          return VerificationType.blueTick;
        case 'goldTick':
          return VerificationType.goldTick;
        case 'blackTick':
          return VerificationType.blackTick;
        default:
          return VerificationType.none;
      }
    }
    return VerificationType.none;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'profiles': {
        'username': username,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'verification_type':
            verificationType.name, // اضافه کردن نوع تیک به خروجی
      },
      'post_owner_id': postOwnerId,
      'parent_comment_id': parentCommentId,
      'replies': replies.map((reply) => reply.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  factory CommentModel.fromJson(String source) =>
      CommentModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'CommentModel(id: $id, content: $content, username: $username, '
        'parentCommentId: $parentCommentId, replies: ${replies.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommentModel &&
        other.id == id &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        createdAt.hashCode ^
        userId.hashCode;
  }

  // متدهای کمکی برای بررسی نوع تیک
  bool get hasBlueBadge =>
      isVerified && verificationType == VerificationType.blueTick;
  bool get hasGoldBadge =>
      isVerified && verificationType == VerificationType.goldTick;
  bool get hasBlackBadge =>
      isVerified && verificationType == VerificationType.blackTick;
  bool get hasAnyBadge =>
      isVerified && verificationType != VerificationType.none;
}

enum VerificationType {
  none, // بدون نشان
  blueTick, // نشان آبی (مدیران و ناظران)
  goldTick, // نشان طلایی (حساب تجاری)
  blackTick // نشان مشکی (تولیدکنندگان محتوا)
}
