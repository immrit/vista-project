import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  // اضافه کردن فیلدهای جدید برای FCM
  final String? openScreen;
  final String? conversationId;
  final String? commentId;
  final String? followerId;

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
    this.openScreen,
    this.conversationId,
    this.commentId,
    this.followerId,
  });

  bool get hasBlueBadge => verificationType == VerificationType.blueTick;
  bool get hasGoldBadge => verificationType == VerificationType.goldTick;
  bool get hasBlackBadge => verificationType == VerificationType.blackTick;

  /// Factory method برای ایجاد NotificationModel از FCM RemoteMessage
  factory NotificationModel.fromFCM(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    // استخراج اطلاعات از payload
    final type = data['type'] ?? '';
    final username = data['username'] ?? data['sender_name'] ?? 'کاربر';
    final avatarUrl = data['avatar_url'] ?? '';
    final content =
        data['message'] ?? data['content'] ?? notification?.body ?? '';
    final postId = data['post_id'] ?? '';
    final conversationId = data['conversation_id'] ?? '';
    final commentId = data['comment_id'] ?? '';
    final followerId = data['follower_id'] ?? '';
    final openScreen = data['open_screen'] ?? '';

    // تعیین verification type بر اساس badges
    VerificationType verificationType = VerificationType.none;
    if (data['has_blue_badge'] == 'true') {
      verificationType = VerificationType.blueTick;
    } else if (data['has_gold_badge'] == 'true') {
      verificationType = VerificationType.goldTick;
    } else if (data['has_black_badge'] == 'true') {
      verificationType = VerificationType.blackTick;
    }

    return NotificationModel(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: data['sender_id'] ?? '',
      recipientId: data['recipient_id'] ?? '',
      content: content,
      createdAt: DateTime.now(),
      type: type,
      username: username,
      userIsVerified: false, // از FCM نمی‌توانیم این مقدار را دریافت کنیم
      avatarUrl: avatarUrl,
      PostId: postId,
      isRead: false,
      verificationType: verificationType,
      openScreen: openScreen,
      conversationId: conversationId,
      commentId: commentId,
      followerId: followerId,
    );
  }

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
      'open_screen': openScreen,
      'conversation_id': conversationId,
      'comment_id': commentId,
      'follower_id': followerId,
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
      if (map.containsKey('user_is_verified')) {
        return map['user_is_verified'] ?? false;
      }
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
      openScreen: map['open_screen'],
      conversationId: map['conversation_id'],
      commentId: map['comment_id'],
      followerId: map['follower_id'],
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
    String? openScreen,
    String? conversationId,
    String? commentId,
    String? followerId,
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
      openScreen: openScreen ?? this.openScreen,
      conversationId: conversationId ?? this.conversationId,
      commentId: commentId ?? this.commentId,
      followerId: followerId ?? this.followerId,
    );
  }

  @override
  List<Object?> get props => [
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
        openScreen,
        conversationId,
        commentId,
        followerId,
      ];
}
