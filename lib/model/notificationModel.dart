import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/avatar_asset_utils.dart';
import '../utils/verification_badge_utils.dart';

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
  final String? deeplink;
  final Map<String, dynamic>? metadata;

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
    this.deeplink,
    this.metadata,
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

  /// Canonicalize notification types from legacy/server variants.
  static String canonicalType(String? rawType) {
    final type = (rawType ?? '').trim().toLowerCase();
    switch (type) {
      case 'post_like':
        return 'like';
      case 'new_comment':
      case 'post_comment':
        return 'comment';
      case 'reply_comment':
        return 'comment_reply';
      case 'comment_mention':
      case 'post_mention':
      case 'mention':
        return 'mention';
      case 'new_message':
      case 'chat_message':
        return 'message';
      case 'message_reaction':
        return 'reaction';
      case 'suggested_follow':
        return 'suggest_follow';
      case 'suggested_post':
        return 'suggest_post';
      default:
        return type;
    }
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

  static bool _isTruthy(dynamic value) =>
      value == true || value?.toString().toLowerCase() == 'true';

  static Map<String, dynamic>? _tryDecodeMap(String raw) {
    if (raw.isEmpty || !raw.trimLeft().startsWith('{')) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static bool _looksLikeSharedPostPayload(Map<String, dynamic>? map) {
    if (map == null) return false;
    return map.containsKey('postId') ||
        map.containsKey('post_id') ||
        map.containsKey('authorName') ||
        map.containsKey('postAuthorName') ||
        map.containsKey('post_author_name');
  }

  static String _sharedPostPreview(Map<String, dynamic>? map) {
    if (map == null) return 'یک پست به اشتراک گذاشته شد';

    final content = (map['content'] ?? map['post_content'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .trim();
    if (content.isNotEmpty) return content;

    final author = (map['authorName'] ??
            map['postAuthorName'] ??
            map['post_author_name'] ??
            '')
        .toString()
        .trim();
    if (author.isNotEmpty) return 'پست اشتراک‌گذاری‌شده از $author';

    return 'یک پست به اشتراک گذاشته شد';
  }

  static String _defaultContentForType(String type) {
    switch (canonicalType(type)) {
      case 'message':
        return 'پیام جدید';
      case 'follow':
        return 'دنبال‌کننده جدید';
      case 'follow_request':
        return 'درخواست دنبال کردن';
      case 'follow_request_accepted':
        return 'درخواست دنبال‌کردن پذیرفته شد';
      case 'like':
        return 'لایک جدید';
      case 'comment':
        return 'نظر جدید';
      case 'comment_reply':
        return 'پاسخ جدید';
      case 'mention':
        return 'شما را تگ کرد';
      default:
        return 'اعلان جدید';
    }
  }

  static String _normalizeContent(
    String raw, {
    String? type,
    String? attachmentType,
  }) {
    final trimmed = raw.trim();
    final normalizedAttachment = (attachmentType ?? '').toLowerCase().trim();

    if (normalizedAttachment == 'post' ||
        normalizedAttachment == 'shared_post') {
      return _sharedPostPreview(_tryDecodeMap(trimmed));
    }

    final decodedMap = _tryDecodeMap(trimmed);
    if (_looksLikeSharedPostPayload(decodedMap)) {
      return _sharedPostPreview(decodedMap);
    }

    switch (normalizedAttachment) {
      case 'image':
        return 'تصویر';
      case 'video':
        return 'ویدیو';
      case 'voice':
      case 'audio':
        return 'پیام صوتی';
      case 'gif':
        return 'GIF';
      case 'file':
      case 'document':
        return 'فایل';
    }

    if (trimmed.isEmpty) {
      return _defaultContentForType(type ?? '');
    }
    return trimmed;
  }

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
        case 'reply_comment':
          type = 'comment_reply';
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

    type = canonicalType(type);

    // استخراج اطلاعات فرستنده
    final username = data['actor_name'] as String? ??
        data['username'] as String? ??
        data['sender_name'] as String? ??
        'کاربر';

    final fullName = data['full_name'] as String? ?? username;
    final avatarUrl = AvatarAssetUtils.resolveUrl(
      data['avatar_url'] as String? ?? data['actor_avatar'] as String?,
    );

    // استخراج ID های مرتبط
    final postId = data['post_id'] as String?;
    final commentId = data['comment_id'] as String?;
    final senderId =
        data['sender_id'] as String? ?? data['actor_id'] as String? ?? '';

    // محتوای نوتیفیکیشن و استخراج conversation_id از nested payload
    String content = '';
    String? conversationId;
    String? messageId;
    Map<String, dynamic>? metadata;

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

    if (data.containsKey('metadata')) {
      try {
        final dynamic raw = data['metadata'];
        if (raw is Map<String, dynamic>) {
          metadata = raw;
        } else if (raw is String && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            metadata = decoded;
          }
        }
      } catch (_) {}
    }

    if (content.isEmpty) {
      content = data['content'] as String? ??
          data['message'] as String? ??
          notification?.body ??
          '';
    }

    // اگر conversation_id از nested payload نیومد، از data مستقیم بگیر
    conversationId ??= data['conversation_id'] as String?;

    content = _normalizeContent(
      content,
      type: type,
      attachmentType: data['attachment_type']?.toString(),
    );

    // تعیین verification type
    final userIsVerified = _isTruthy(data['is_verified']);
    dynamic verificationRaw = data['verification_type'];
    if (_isTruthy(data['has_blue_badge'])) {
      verificationRaw = 'blueTick';
    } else if (_isTruthy(data['has_gold_badge'])) {
      verificationRaw = 'goldTick';
    } else if (_isTruthy(data['has_black_badge'])) {
      verificationRaw = 'blackTick';
    }

    final verificationType = _mapResolvedType(resolveVerificationBadgeType(
      isVerified: userIsVerified,
      verificationType: verificationRaw,
      role: data['role']?.toString(),
    ));

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
      userIsVerified: userIsVerified,
      avatarUrl: avatarUrl,
      postId: postId,
      commentId: commentId,
      parentCommentId: data['parent_comment_id'] as String?,
      isRead: false,
      verificationType: verificationType,
      openScreen: data['open_screen'] as String?,
      conversationId: conversationId, // ✅ استفاده از extracted value
      followerId: data['follower_id'] as String?,
      deeplink: data['deeplink'] as String?,
      metadata: metadata,
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
      'deeplink': deeplink,
      'metadata': metadata,
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
      'deeplink': deeplink,
      'metadata': metadata,
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
      content: _normalizeContent(
        json['content']?.toString() ?? '',
        type: json['type']?.toString(),
        attachmentType: json['attachment_type']?.toString(),
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      type: canonicalType(json['type']?.toString()),
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      userIsVerified: _isTruthy(json['is_verified']),
      avatarUrl: AvatarAssetUtils.resolveUrl(
        json['avatar_url'] ?? json['actor_avatar'],
      ),
      postId: json['post_id'],
      commentId: json['comment_id'],
      parentCommentId: json['parent_comment_id'],
      isRead: json['is_read'] ?? false,
      verificationType: _mapResolvedType(resolveVerificationBadgeType(
        isVerified: _isTruthy(json['is_verified']),
        verificationType: json['verification_type'],
        role: json['role']?.toString(),
      )),
      openScreen: json['open_screen'],
      conversationId: json['conversation_id'],
      followerId: json['follower_id'],
      deeplink: json['deeplink'],
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : null,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    // استخراج اطلاعات sender
    final sender = map['sender'] as Map<String, dynamic>?;

    // تبدیل verification type
    final userIsVerified = _isTruthy(sender?['is_verified']);
    final verificationType = _mapResolvedType(resolveVerificationBadgeType(
      isVerified: userIsVerified,
      verificationType: sender?['verification_type'],
      role: sender?['role']?.toString(),
    ));

    return NotificationModel(
      id: map['id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      recipientId: map['recipient_id'] as String? ?? '',
      content: _normalizeContent(
        map['content'] as String? ?? '',
        type: map['type']?.toString(),
        attachmentType: map['attachment_type']?.toString(),
      ),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      type: canonicalType(map['type']?.toString()),
      username: sender?['username'] as String? ?? '',
      fullName: sender?['full_name'] as String? ?? '',
      userIsVerified: userIsVerified,
      avatarUrl: AvatarAssetUtils.resolveUrl(sender?['avatar_url']),
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      parentCommentId: map['parent_comment_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      verificationType: verificationType,
      openScreen: map['open_screen'] as String?,
      conversationId: map['conversation_id'] as String?,
      followerId: map['follower_id'] as String?,
      deeplink: map['deeplink'] as String?,
      metadata: map['metadata'] is Map<String, dynamic>
          ? map['metadata'] as Map<String, dynamic>
          : map['metadata'] is Map
              ? Map<String, dynamic>.from(map['metadata'] as Map)
              : null,
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
    String? deeplink,
    Map<String, dynamic>? metadata,
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
      deeplink: deeplink ?? this.deeplink,
      metadata: metadata ?? this.metadata,
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
        deeplink,
        metadata,
      ];
}
