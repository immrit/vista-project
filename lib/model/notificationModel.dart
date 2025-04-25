import 'package:equatable/equatable.dart';

enum VerificationType { none, blueTick, goldTick, blackTick }

class NotificationModel extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime createdAt;
  final String type;
  final String username;
  final bool userIsVerified;
  final String avatarUrl;
  final String PostId;
  final bool isRead;
  final VerificationType verificationType;

  const NotificationModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    required this.type,
    required this.username,
    required this.userIsVerified,
    required this.avatarUrl,
    required this.PostId,
    required this.isRead,
    required this.verificationType,
  });

  bool get hasBlueBadge => verificationType == VerificationType.blueTick;
  bool get hasGoldBadge => verificationType == VerificationType.goldTick;
  bool get hasBlackBadge => verificationType == VerificationType.blackTick;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'type': type,
      'username': username,
      'user_is_verified': userIsVerified,
      'avatar_url': avatarUrl,
      'post_id': PostId,
      'is_read': isRead,
      'verification_type': verificationType.toString().split('.').last,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    VerificationType parseVerificationType(dynamic value) {
      if (value == null) return VerificationType.none;
      switch (value.toString()) {
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

    String getSenderId() {
      if (map.containsKey('sender_id')) return map['sender_id'];
      return '';
    }

    String getUsername() {
      if (map.containsKey('username')) return map['username'] ?? '';
      if (map.containsKey('sender') && map['sender'] != null) {
        final senderMap = map['sender'] as Map<String, dynamic>;
        return senderMap['username'] ?? '';
      }
      return '';
    }

    String getAvatarUrl() {
      if (map.containsKey('avatar_url')) return map['avatar_url'] ?? '';
      if (map.containsKey('sender') && map['sender'] != null) {
        final senderMap = map['sender'] as Map<String, dynamic>;
        return senderMap['avatar_url'] ?? '';
      }
      return '';
    }

    bool getUserIsVerified() {
      if (map.containsKey('user_is_verified'))
        return map['user_is_verified'] ?? false;
      if (map.containsKey('sender') && map['sender'] != null) {
        final senderMap = map['sender'] as Map<String, dynamic>;
        return senderMap['is_verified'] ?? false;
      }
      return false;
    }

    VerificationType getVerificationType() {
      if (map.containsKey('verification_type')) {
        return parseVerificationType(map['verification_type']);
      }
      if (map.containsKey('sender') && map['sender'] != null) {
        final senderMap = map['sender'] as Map<String, dynamic>;
        return parseVerificationType(senderMap['verification_type']);
      }
      return VerificationType.none;
    }

    return NotificationModel(
      id: map['id'] ?? '',
      senderId: getSenderId(),
      recipientId: map['recipient_id'] ?? '',
      content: map['content'] ?? '',
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      type: map['type'] ?? '',
      username: getUsername(),
      userIsVerified: getUserIsVerified(),
      avatarUrl: getAvatarUrl(),
      PostId: map['post_id'] ?? '',
      isRead: map['is_read'] ?? false,
      verificationType: getVerificationType(),
    );
  }

  // اضافه کردن متد copyWith برای بروزرسانی آسان اعلان‌ها
  NotificationModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? createdAt,
    String? type,
    String? username,
    bool? userIsVerified,
    String? avatarUrl,
    String? PostId,
    bool? isRead,
    VerificationType? verificationType,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      username: username ?? this.username,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      PostId: PostId ?? this.PostId,
      isRead: isRead ?? this.isRead,
      verificationType: verificationType ?? this.verificationType,
    );
  }

  @override
  List<Object> get props => [
        id,
        senderId,
        recipientId,
        content,
        createdAt,
        type,
        username,
        userIsVerified,
        avatarUrl,
        PostId,
        isRead,
        verificationType,
      ];
}
