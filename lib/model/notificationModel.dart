import 'dart:convert';
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
  final String fullName; // ✅ اضافه شد
  final bool userIsVerified;
  final String? avatarUrl; // ✅ nullable شد
  final String? postId; // ✅ camelCase و nullable
  final String? commentId;
  final String? parentCommentId; // ✅ اضافه شد
  final bool isRead;
  final VerificationType verificationType;
  // اضافه کردن فیلدهای جدید برای FCM
  final String? openScreen;
  final String? conversationId;
  final String? followerId;

  // Getter برای backward compatibility
  String get PostId => postId ?? '';

  const NotificationModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    required this.type,
    required this.username,
    required this.fullName,
    required this.userIsVerified,
    this.avatarUrl,
    this.postId,
    this.commentId,
    this.parentCommentId,
    required this.isRead,
    required this.verificationType,
    this.openScreen,
    this.conversationId,
    this.followerId,
  });

  factory NotificationModel.empty() {
    return NotificationModel(
      id: '',
      senderId: '',
      recipientId: '',
      content: '',
      createdAt: DateTime.now(),
      type: '',
      username: '',
      fullName: '',
      userIsVerified: false,
      avatarUrl: null,
      postId: null,
      commentId: null,
      parentCommentId: null,
      isRead: false,
      verificationType: VerificationType.none,
    );
  }

  bool get hasBlueBadge => verificationType == VerificationType.blueTick;
  bool get hasGoldBadge => verificationType == VerificationType.goldTick;
  bool get hasBlackBadge => verificationType == VerificationType.blackTick;

  /// Factory method برای ایجاد NotificationModel از FCM RemoteMessage
  factory NotificationModel.fromFCM(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    // استخراج نوع اعلان
    String type = '';
    if (data.containsKey('type')) {
      type = data['type'] as String;
    } else {
      // تبدیل نوع‌های قدیمی به جدید
      final oldType = data['notification_type'] as String?;
      switch (oldType) {
        case 'post_like':
          type = 'like';
          break;
        case 'post_comment':
          type = 'comment';
          break;
        case 'follow':
          type = 'follow';
          break;
        case 'new_message':
          type = 'message';
          break;
        case 'message_reaction':
          type = 'reaction';
          break;
        default:
          type = oldType ?? 'unknown';
      }
    }

    // استخراج اطلاعات فرستنده
    final username = data['actor_name'] as String? ??
        data['username'] as String? ??
        data['sender_name'] as String? ??
        'کاربر';

    final fullName = data['full_name'] as String? ?? username;
    final avatarUrl = data['avatar_url'] as String?;

    // استخراج ID های مرتبط
    final postId = data['post_id'] as String?;
    final commentId = data['comment_id'] as String?;
    final senderId =
        data['sender_id'] as String? ?? data['actor_id'] as String? ?? '';

    // محتوای نوتیفیکیشن و استخراج conversation_id از nested payload
    String content = '';
    String? conversationId;
    String? messageId;

    if (data.containsKey('payload')) {
      try {
        final payload = data['payload'];
        if (payload is String) {
          final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
          content = payloadMap['content_preview'] as String? ?? '';
          conversationId = payloadMap['conversation_id'] as String?;
          messageId = payloadMap['message_id'] as String?;
          print('✅ Nested payload parsed:');
          print('   conversation_id: $conversationId');
          print('   message_id: $messageId');
          print('   content_preview: $content');
        } else if (payload is Map) {
          content = payload['content_preview'] as String? ?? '';
          conversationId = payload['conversation_id'] as String?;
          messageId = payload['message_id'] as String?;
        }
      } catch (e) {
        print('⚠️ خطا در parse کردن nested payload: $e');
      }
    }

    if (content.isEmpty) {
      content = data['content'] as String? ??
          data['message'] as String? ??
          notification?.body ??
          '';
    }

    // اگر conversation_id از nested payload نیومد، از data مستقیم بگیر
    conversationId ??= data['conversation_id'] as String?;

    // تعیین verification type
    VerificationType verificationType = VerificationType.none;
    if (data['has_blue_badge'] == 'true') {
      verificationType = VerificationType.blueTick;
    } else if (data['has_gold_badge'] == 'true') {
      verificationType = VerificationType.goldTick;
    } else if (data['has_black_badge'] == 'true') {
      verificationType = VerificationType.blackTick;
    }

    return NotificationModel(
      id: messageId ??
          data['notification_id'] ??
          data['message_id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      recipientId: data['receiver_id'] as String? ??
          data['recipient_id'] as String? ??
          '',
      content: content,
      createdAt: _parseDate(data['timestamp']),
      type: type,
      username: username,
      fullName: fullName,
      userIsVerified:
          data['is_verified'] == 'true' || data['is_verified'] == true,
      avatarUrl: avatarUrl ?? data['actor_avatar'] as String?,
      postId: postId,
      commentId: commentId,
      parentCommentId: data['parent_comment_id'] as String?,
      isRead: false,
      verificationType: verificationType,
      openScreen: data['open_screen'] as String?,
      conversationId: conversationId, // ✅ استفاده از extracted value
      followerId: data['follower_id'] as String?,
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
      'post_id': postId,
      'comment_id': commentId,
      'parent_comment_id': parentCommentId,
      'is_read': isRead,
      'sender': {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_verified': userIsVerified,
        'verification_type': verificationType == VerificationType.blueTick
            ? 'blue'
            : verificationType == VerificationType.goldTick
                ? 'gold'
                : verificationType == VerificationType.blackTick
                    ? 'black'
                    : null,
      },
    };
  }

  /// تبدیل به JSON برای payload
  Map<String, dynamic> toPayloadJson() {
    return {
      'id': id,
      'notification_id': id, // برای backward compatibility
      'type': type,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'post_id': postId,
      'comment_id': commentId,
      'parent_comment_id': parentCommentId,
      'conversation_id': conversationId,
      'follower_id': followerId,
      'content': content,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_verified': userIsVerified.toString(),
      'verification_type': verificationType == VerificationType.blueTick
          ? 'blue'
          : verificationType == VerificationType.goldTick
              ? 'gold'
              : verificationType == VerificationType.blackTick
                  ? 'black'
                  : 'none',
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'open_screen': openScreen,
    };
  }

  /// ساخت از JSON payload
  factory NotificationModel.fromPayloadJson(Map<String, dynamic> json) {
    print('🔨 NotificationModel.fromPayloadJson:');
    json.forEach((key, value) {
      print('   $key: $value (${value.runtimeType})');
    });

    return NotificationModel(
      id: json['id'] ?? json['notification_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      recipientId: json['recipient_id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      type: json['type'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      userIsVerified:
          json['is_verified'] == 'true' || json['is_verified'] == true,
      avatarUrl: json['avatar_url'],
      postId: json['post_id'],
      commentId: json['comment_id'],
      parentCommentId: json['parent_comment_id'],
      isRead: json['is_read'] ?? false,
      verificationType: json['verification_type'] == 'blue'
          ? VerificationType.blueTick
          : json['verification_type'] == 'gold'
              ? VerificationType.goldTick
              : json['verification_type'] == 'black'
                  ? VerificationType.blackTick
                  : VerificationType.none,
      openScreen: json['open_screen'],
      conversationId: json['conversation_id'],
      followerId: json['follower_id'],
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    // استخراج اطلاعات sender
    final sender = map['sender'] as Map<String, dynamic>?;

    // تبدیل verification type
    VerificationType verificationType = VerificationType.none;
    if (sender != null) {
      final verificationTypeStr = sender['verification_type'] as String?;
      switch (verificationTypeStr) {
        case 'blue':
          verificationType = VerificationType.blueTick;
          break;
        case 'gold':
          verificationType = VerificationType.goldTick;
          break;
        case 'black':
          verificationType = VerificationType.blackTick;
          break;
      }
    }

    return NotificationModel(
      id: map['id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      recipientId: map['recipient_id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      type: map['type'] as String? ?? '',
      username: sender?['username'] as String? ?? '',
      fullName: sender?['full_name'] as String? ?? '',
      userIsVerified: sender?['is_verified'] as bool? ?? false,
      avatarUrl: sender?['avatar_url'] as String?,
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      parentCommentId: map['parent_comment_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      verificationType: verificationType,
      openScreen: map['open_screen'] as String?,
      conversationId: map['conversation_id'] as String?,
      followerId: map['follower_id'] as String?,
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
    String? fullName,
    bool? userIsVerified,
    String? avatarUrl,
    String? postId,
    String? commentId,
    String? parentCommentId,
    bool? isRead,
    VerificationType? verificationType,
    String? openScreen,
    String? conversationId,
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
      fullName: fullName ?? this.fullName,
      userIsVerified: userIsVerified ?? this.userIsVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      isRead: isRead ?? this.isRead,
      verificationType: verificationType ?? this.verificationType,
      openScreen: openScreen ?? this.openScreen,
      conversationId: conversationId ?? this.conversationId,
      followerId: followerId ?? this.followerId,
    );
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();

    // 1. اگر عدد باشد (میلی‌ثانیه)
    if (date is int) {
      return DateTime.fromMillisecondsSinceEpoch(date);
    }

    // 2. اگر رشته باشد
    if (date is String) {
      // الف: بررسی اگر رشته عددی است (timestamp string)
      if (RegExp(r'^\d+$').hasMatch(date)) {
        try {
          final int timestamp = int.parse(date);
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        } catch (_) {}
      }

      // ب: فرمت استاندارد ISO
      try {
        return DateTime.parse(date);
      } catch (_) {}
    }

    // fallback
    return DateTime.now();
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
        fullName,
        userIsVerified,
        avatarUrl,
        postId,
        commentId,
        parentCommentId,
        isRead,
        verificationType,
        openScreen,
        conversationId,
        followerId,
      ];
}
