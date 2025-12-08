// lib/model/message_model.dart
import 'dart:convert';
import 'message_reaction_ui.dart';

/// مدل داده‌های پست اشتراک‌گذاری شده
class SharedPostData {
  final String postId;
  final String postContent;
  final String? postImageUrl;
  final String? postVideoUrl;
  final String postAuthorName;
  final String postAuthorUsername;
  final String? postAuthorAvatar;
  final DateTime postCreatedAt;
  final int likeCount;
  final int commentCount;
  final bool isVerified;
  final String verificationType;

  const SharedPostData({
    required this.postId,
    required this.postContent,
    this.postImageUrl,
    this.postVideoUrl,
    required this.postAuthorName,
    required this.postAuthorUsername,
    this.postAuthorAvatar,
    required this.postCreatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isVerified = false,
    this.verificationType = 'none',
  });

  factory SharedPostData.fromJson(Map<String, dynamic> json) {
    return SharedPostData(
      postId: json['post_id'] ?? '',
      postContent: json['post_content'] ?? '',
      postImageUrl: json['post_image_url'],
      postVideoUrl: json['post_video_url'],
      postAuthorName: json['post_author_name'] ?? '',
      postAuthorUsername: json['post_author_username'] ?? '',
      postAuthorAvatar: json['post_author_avatar'],
      postCreatedAt: json['post_created_at'] != null
          ? DateTime.parse(json['post_created_at'])
          : DateTime.now(),
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      verificationType: json['verification_type'] ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'post_content': postContent,
      'post_image_url': postImageUrl,
      'post_video_url': postVideoUrl,
      'post_author_name': postAuthorName,
      'post_author_username': postAuthorUsername,
      'post_author_avatar': postAuthorAvatar,
      'post_created_at': postCreatedAt.toIso8601String(),
      'like_count': likeCount,
      'comment_count': commentCount,
      'is_verified': isVerified,
      'verification_type': verificationType,
    };
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final int? duration; // مدت زمان فایل صوتی (ثانیه)
  final bool isRead;
  final bool isSent;
  final bool isDelivered; // نشان‌دهنده اینکه پیام به دستگاه گیرنده رسیده
  final bool isSeen; // نشان‌دهنده اینکه پیام توسط گیرنده دیده شده
  final String? senderName;
  final String? senderAvatar;
  final bool isMe;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isPending;
  final bool? isFailed;
  final String? localId;
  final int retryCount;
  final String? errorMessage; // پیام خطای ارسال برای نمایش به کاربر
  final DateTime? lastRetryTime; // آخرین زمان تلاش مجدد

  // فیلدهای فوروارد
  final bool isForwarded;
  final String? originalSenderId;
  final String? forwardedFromSenderName;
  final String? originalMessageId;

  // Typing indicators برای نشان دادن کاربران در حال تایپ
  final Map<String, DateTime>? typingUsers;

  // ری‌اکشن‌های پیام - Map از emoji به لیست userId ها
  final Map<String, List<String>> reactions;

  // فیلدهای جدید برای پشتیبانی از Shared Post
  final String? messageType; // 'text', 'image', 'video', 'voice', 'sharedPost'
  final SharedPostData? sharedPostData; // داده‌های پست اشتراک‌گذاری شده

  // تبدیل reactions به UI model
  List<MessageReactionUI> getReactionsList(String currentUserId) {
    return reactions.entries.map((entry) {
      return MessageReactionUI(
        emoji: entry.key,
        userIds: entry.value,
        hasCurrentUser: entry.value.contains(currentUserId),
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count)); // مرتب‌سازی بر اساس تعداد
  }

  bool hasReactions() => reactions.isNotEmpty;

  /// بررسی اینکه آیا پیام یک پست اشتراک‌گذاری شده است
  bool get isSharedPost =>
      messageType == 'sharedPost' && sharedPostData != null;

  factory MessageModel.empty() {
    return MessageModel(
      id: '',
      conversationId: '',
      senderId: '',
      content: '',
      createdAt: DateTime.now(),
      isMe: false,
    );
  }

  // پارس کردن reactions از JSON
  static Map<String, List<String>> _parseReactions(dynamic reactionsJson) {
    if (reactionsJson == null) return {};

    try {
      if (reactionsJson is Map) {
        // اگر reactions به صورت Map<String, List<String>> باشد
        return Map<String, List<String>>.from(reactionsJson.map((key, value) {
          if (value is List) {
            return MapEntry(key, List<String>.from(value));
          } else {
            return MapEntry(key, <String>[]);
          }
        }));
      } else if (reactionsJson is List) {
        // اگر reactions به صورت List از MessageReaction باشد
        final Map<String, List<String>> parsedReactions = {};
        for (var reactionJson in reactionsJson) {
          if (reactionJson is Map<String, dynamic>) {
            final emoji = reactionJson['emoji'] as String?;
            final userId = reactionJson['user_id'] as String?;
            if (emoji != null && userId != null) {
              parsedReactions[emoji] ??= [];
              parsedReactions[emoji]!.add(userId);
            }
          }
        }
        return parsedReactions;
      }
    } catch (e) {
      print('خطا در پارس کردن reactions: $e');
    }

    return {};
  }

  // پارس کردن shared post data از JSON
  static SharedPostData? _parseSharedPostData(dynamic sharedPostJson) {
    if (sharedPostJson == null) return null;

    try {
      Map<String, dynamic> data;

      if (sharedPostJson is String) {
        // اگر به صورت JSON string ذخیره شده باشد
        data = json.decode(sharedPostJson);
      } else if (sharedPostJson is Map<String, dynamic>) {
        data = sharedPostJson;
      } else {
        return null;
      }

      return SharedPostData.fromJson(data);
    } catch (e) {
      print('خطا در پارس کردن shared post data: $e');
      return null;
    }
  }

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.duration,
    this.isRead = false,
    this.isSent = true,
    this.isDelivered = false,
    this.isSeen = false,
    this.senderName,
    this.senderAvatar,
    required this.isMe,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.isPending = false,
    this.isFailed,
    this.localId,
    this.retryCount = 0,
    this.errorMessage,
    this.lastRetryTime,
    this.isForwarded = false,
    this.originalSenderId,
    this.forwardedFromSenderName,
    this.originalMessageId,
    this.typingUsers,
    this.reactions = const {},
    this.messageType,
    this.sharedPostData,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    String conversationId =
        json['conversation_id'] ?? json['conversations_id'] ?? '';

    return MessageModel(
      id: json['id'],
      conversationId: conversationId,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      isSent: json['is_sent'] ?? true,
      isDelivered: json['is_delivered'] as bool? ?? false,
      isSeen: json['is_seen'] as bool? ?? false,
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      attachmentFileName: json['attachment_file_name'] as String?,
      duration: json['duration'] as int?,
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
      isMe: json['sender_id'] == currentUserId,
      replyToMessageId: json['reply_to_message_id'],
      replyToContent: json['reply_to_content'],
      replyToSenderName: json['reply_to_sender_name'],
      localId: json['local_id'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
      isPending: json['is_pending'] as bool? ?? false,
      isFailed: json['is_failed'] as bool?,
      errorMessage: json['error_message'] as String?,
      lastRetryTime: json['last_retry_time'] != null
          ? DateTime.parse(json['last_retry_time'] as String)
          : null,
      isForwarded: json['is_forwarded'] as bool? ?? false,
      originalSenderId: json['original_sender_id'] as String?,
      forwardedFromSenderName: json['forwarded_from_sender_name'] as String?,
      originalMessageId: json['original_message_id'] as String?,
      typingUsers: json['typing_users'] != null
          ? Map<String, DateTime>.from(json['typing_users'])
          : null,
      reactions: _parseReactions(json['reactions']),
      messageType: json['message_type'] as String?,
      sharedPostData: _parseSharedPostData(json['shared_post_data']),
    );
  }

  factory MessageModel.temporary({
    required String tempId,
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    int? duration,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? senderName,
    String? senderAvatar,
    DateTime? createdAt,
    bool isRead = false,
    bool isSent = true,
    int retryCount = 0,
    String? messageType,
    SharedPostData? sharedPostData,
  }) {
    return MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      duration: duration,
      isRead: false,
      isSent: false,
      isPending: true,
      localId: tempId,
      senderName: senderName ?? 'من',
      senderAvatar: senderAvatar,
      isMe: true,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      retryCount: retryCount,
      messageType: messageType,
      sharedPostData: sharedPostData,
    );
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    int? duration,
    bool? isRead,
    bool? isSent,
    bool? isDelivered,
    bool? isSeen,
    String? senderName,
    String? senderAvatar,
    bool? isMe,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool? isPending,
    bool? isFailed,
    String? localId,
    int? retryCount,
    String? errorMessage,
    DateTime? lastRetryTime,
    Map<String, DateTime>? typingUsers,
    Map<String, List<String>>? reactions,
    String? messageType,
    SharedPostData? sharedPostData,
    bool? isForwarded,
    String? originalSenderId,
    String? forwardedFromSenderName,
    String? originalMessageId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      duration: duration ?? this.duration,
      isRead: isRead ?? this.isRead,
      isSent: isSent ?? this.isSent,
      isDelivered: isDelivered ?? this.isDelivered,
      isSeen: isSeen ?? this.isSeen,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMe: isMe ?? this.isMe,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
      localId: localId ?? this.localId,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      lastRetryTime: lastRetryTime ?? this.lastRetryTime,
      typingUsers: typingUsers ?? this.typingUsers,
      reactions: reactions ?? this.reactions,
      messageType: messageType ?? this.messageType,
      sharedPostData: sharedPostData ?? this.sharedPostData,
      isForwarded: isForwarded ?? this.isForwarded,
      originalSenderId: originalSenderId ?? this.originalSenderId,
      forwardedFromSenderName:
          forwardedFromSenderName ?? this.forwardedFromSenderName,
      originalMessageId: originalMessageId ?? this.originalMessageId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'attachment_file_name': attachmentFileName,
      'duration': duration,
      'is_read': isRead,
      'is_sent': isSent,
      'is_delivered': isDelivered,
      'is_seen': isSeen,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'reply_to_message_id': replyToMessageId,
      'reply_to_content': replyToContent,
      'reply_to_sender_name': replyToSenderName,
      'is_pending': isPending,
      'is_failed': isFailed,
      'local_id': localId,
      'retry_count': retryCount,
      'error_message': errorMessage,
      'last_retry_time': lastRetryTime?.toIso8601String(),
      'typing_users': typingUsers,
      'reactions': reactions,
      'message_type': messageType,
      'shared_post_data':
          sharedPostData != null ? json.encode(sharedPostData!.toJson()) : null,
      'is_forwarded': isForwarded,
      'original_sender_id': originalSenderId,
      'forwarded_from_sender_name': forwardedFromSenderName,
      'original_message_id': originalMessageId,
    };
  }
}
