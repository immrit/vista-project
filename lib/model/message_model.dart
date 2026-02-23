// lib/model/message_model.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/telegram_read_receipt_service.dart';
import 'message_reaction_ui.dart';
import '../features/chat/widgets/media_message_bubble.dart';

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
  final String? role;

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
    this.role,
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
      role: json['role']?.toString(),
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
      'role': role,
    };
  }
}

/// مدل داده‌های پاسخ به استوری (مشابه دایرکت ویستا)
class StoryReplyData {
  final String storyId;
  final String storyOwnerId;
  final String storyOwnerUsername;
  final String? storyOwnerAvatarUrl;
  final String storyThumbnailUrl;
  final String storyMediaType;
  final DateTime storyCreatedAt;
  final DateTime? storyExpiresAt;
  final int? storyDurationHours;
  final String replyKind;
  final String? elementId;
  final String? questionText;
  final String? answerText;
  final String? respondentId;
  final String? respondentUsername;

  const StoryReplyData({
    required this.storyId,
    required this.storyOwnerId,
    required this.storyOwnerUsername,
    this.storyOwnerAvatarUrl,
    required this.storyThumbnailUrl,
    required this.storyMediaType,
    required this.storyCreatedAt,
    this.storyExpiresAt,
    this.storyDurationHours,
    this.replyKind = 'reply',
    this.elementId,
    this.questionText,
    this.answerText,
    this.respondentId,
    this.respondentUsername,
  });

  factory StoryReplyData.fromJson(Map<String, dynamic> json) {
    final createdAt = json['story_created_at'] != null
        ? DateTime.parse(json['story_created_at'])
        : DateTime.now();

    final durationHours = (json['story_duration_hours'] as num?)?.toInt() ??
        (json['duration_hours'] as num?)?.toInt();

    DateTime? expiresAt;
    if (json['story_expires_at'] != null) {
      expiresAt = DateTime.parse(json['story_expires_at']);
    } else if (durationHours != null && durationHours > 0) {
      expiresAt = createdAt.add(Duration(hours: durationHours));
    }

    return StoryReplyData(
      storyId: json['story_id'] ?? '',
      storyOwnerId: json['story_owner_id'] ?? '',
      storyOwnerUsername: json['story_owner_username'] ?? '',
      storyOwnerAvatarUrl: json['story_owner_avatar_url'] as String?,
      storyThumbnailUrl: json['story_thumbnail_url'] ?? '',
      storyMediaType: json['story_media_type'] ?? 'image',
      storyCreatedAt: createdAt,
      storyExpiresAt: expiresAt,
      storyDurationHours: durationHours,
      replyKind: (json['reply_kind'] ?? 'reply').toString(),
      elementId: json['element_id']?.toString(),
      questionText: json['question_text']?.toString(),
      answerText: json['answer_text']?.toString() ?? json['answer']?.toString(),
      respondentId: json['respondent_id']?.toString(),
      respondentUsername: json['respondent_username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'story_id': storyId,
        'story_owner_id': storyOwnerId,
        'story_owner_username': storyOwnerUsername,
        'story_owner_avatar_url': storyOwnerAvatarUrl,
        'story_thumbnail_url': storyThumbnailUrl,
        'story_media_type': storyMediaType,
        'story_created_at': storyCreatedAt.toIso8601String(),
        'story_expires_at': storyExpiresAt?.toIso8601String(),
        'story_duration_hours': storyDurationHours,
        'reply_kind': replyKind,
        'element_id': elementId,
        'question_text': questionText,
        'answer_text': answerText,
        'respondent_id': respondentId,
        'respondent_username': respondentUsername,
      };
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? audioUrl; // URL فایل صوتی (ویس) - از دیتابیس audio_url
  final String? attachmentType;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioAlbum;
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
  final String?
      messageType; // 'text', 'image', 'video', 'voice', 'sharedPost', 'storyReply'
  final SharedPostData? sharedPostData; // داده‌های پست اشتراک‌گذاری شده
  final StoryReplyData? storyReplyData; // داده‌های پاسخ به استوری

  // فیلدهای حذف پیام (مشابه ویستا)
  final bool
      deletedGlobally; // حذف د‌و‌طرفه: اگر true باشد، پیام باید برای همه حذف شود
  final List<String>
      deletedForUserIds; // حذف یک‌طرفه: شامل user_id کاربرانی که پیام را فقط برای خود حذف کرده‌اند

  // ✅ فیلدهای جدید برای نمایش تصاویر با پیشرفت آپلود (مثل ویستا)
  final String? localImagePath; // مسیر محلی تصویر (قبل از آپلود)
  final String? localFilePath; // مسیر محلی فایل (قبل از آپلود)
  final double? uploadProgress; // پیشرفت آپلود (0.0 تا 1.0)
  final bool isUploading; // آیا در حال آپلود است؟

  // ✅ ValueNotifier برای status - فقط این rebuild میشه
  late final ValueNotifier<MessageDeliveryStatus> _statusNotifier;

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

  /// بررسی اینکه آیا پیام یک پاسخ به استوری است
  bool get isStoryReply =>
      messageType == 'storyReply' && storyReplyData != null;

  /// تشخیص اینکه آیا پیام حاوی عکس است
  bool get isImage {
    if (attachmentType == null && messageType == null) return false;
    return (attachmentType != null && attachmentType!.startsWith('image')) ||
        messageType == 'image';
  }

  /// تشخیص اینکه آیا پیام حاوی ویدیو است
  bool get isVideo {
    if (attachmentType == null && messageType == null) return false;
    return (attachmentType != null && attachmentType!.startsWith('video')) ||
        messageType == 'video';
  }

  /// گرفتن نوع مدیا برای ویجت MediaMessageBubble
  MediaType get mediaTypeEnum {
    if (isVideo) return MediaType.video;
    // اگر گیف دارید شرط آن را اضافه کنید
    return MediaType.image;
  }

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

  // پارس کردن story reply data از JSON
  static StoryReplyData? _parseStoryReplyData(dynamic storyReplyJson) {
    if (storyReplyJson == null) return null;

    try {
      Map<String, dynamic> data;

      if (storyReplyJson is String) {
        data = json.decode(storyReplyJson);
      } else if (storyReplyJson is Map<String, dynamic>) {
        data = storyReplyJson;
      } else {
        return null;
      }

      return StoryReplyData.fromJson(data);
    } catch (e) {
      print('خطا در پارس کردن story reply data: $e');
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
    this.audioUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
    this.audioTitle,
    this.audioArtist,
    this.audioAlbum,
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
    this.storyReplyData,
    this.deletedGlobally = false,
    this.deletedForUserIds = const [],
    this.localImagePath,
    this.localFilePath,
    this.uploadProgress,
    this.isUploading = false,
  }) {
    // ✅ Initialize status notifier با مقدار محاسبه شده
    _statusNotifier = ValueNotifier(_calculateDeliveryStatus());
  }

  // ✅ Getter برای ValueNotifier
  ValueNotifier<MessageDeliveryStatus> get statusNotifier => _statusNotifier;

  // ✅ Getter برای مقدار فعلی status
  MessageDeliveryStatus get deliveryStatus => _statusNotifier.value;

  // ✅ محاسبه MessageDeliveryStatus از فیلدهای status
  MessageDeliveryStatus _calculateDeliveryStatus() {
    if (isFailed == true) {
      return MessageDeliveryStatus.failed;
    }
    if (isPending) {
      return MessageDeliveryStatus.pending;
    }
    if (isSeen) {
      return MessageDeliveryStatus.read;
    }
    if (isDelivered) {
      return MessageDeliveryStatus.delivered;
    }
    if (isSent) {
      return MessageDeliveryStatus.sent;
    }
    return MessageDeliveryStatus.pending;
  }

  // ✅ متد برای آپدیت status - فقط ValueNotifier رو trigger میکنه
  void updateStatus({
    bool? pending,
    bool? seen,
    bool? failed,
    bool? sent,
    bool? delivered,
  }) {
    // محاسبه status جدید
    final newStatus = _calculateDeliveryStatusFromFields(
      pending: pending ?? isPending,
      seen: seen ?? isSeen,
      failed: failed ?? isFailed,
      sent: sent ?? isSent,
      delivered: delivered ?? isDelivered,
    );

    // فقط اگر تغییر کرده باشه، ValueNotifier رو آپدیت کن
    if (_statusNotifier.value != newStatus) {
      _statusNotifier.value = newStatus;
    }
  }

  // ✅ محاسبه status از فیلدها
  MessageDeliveryStatus _calculateDeliveryStatusFromFields({
    required bool pending,
    required bool seen,
    bool? failed,
    required bool sent,
    required bool delivered,
  }) {
    if (failed == true) {
      return MessageDeliveryStatus.failed;
    }
    if (pending) {
      return MessageDeliveryStatus.pending;
    }
    if (seen) {
      return MessageDeliveryStatus.read;
    }
    if (delivered) {
      return MessageDeliveryStatus.delivered;
    }
    if (sent) {
      return MessageDeliveryStatus.sent;
    }
    return MessageDeliveryStatus.pending;
  }

  // ✅ Dispose کردن notifier (برای جلوگیری از memory leak)
  void dispose() {
    _statusNotifier.dispose();
  }

  factory MessageModel.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    Map<String, dynamic>? extractProfile(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is Map<String, dynamic>) {
          return first;
        }
      }
      return null;
    }

    String conversationId =
        json['conversation_id'] ?? json['conversations_id'] ?? '';

    final profile = extractProfile(json['profiles']);
    final profileUsername = profile?['username']?.toString().trim() ?? '';
    final profileFullName = profile?['full_name']?.toString().trim() ?? '';
    final profileName =
        profileFullName.isNotEmpty ? profileFullName : profileUsername;
    final profileAvatar = profile?['avatar_url']?.toString().trim();

    // ✅ بهینه‌سازی: پارس کردن دیتا همینجا (فقط یکبار)
    SharedPostData? parsedSharedPost =
        _parseSharedPostData(json['shared_post_data']);

    // اگر shared_post_data خالی بود ولی content فرمت JSON داشت (پشتیبانی از ورژن‌های قدیمی)
    if (parsedSharedPost == null) {
      final content = json['content'] as String? ?? '';
      if (content.trim().startsWith('{') && content.contains('postId')) {
        try {
          final contentJson = jsonDecode(content) as Map<String, dynamic>?;
          if (contentJson != null) {
            // تبدیل فرمت قدیمی به SharedPostData
            parsedSharedPost = SharedPostData.fromJson({
              'post_id': contentJson['postId'] ?? '',
              'post_content': contentJson['content'] ?? '',
              'post_image_url': contentJson['mediaUrls'] != null &&
                      (contentJson['mediaUrls'] as List).isNotEmpty
                  ? (contentJson['mediaUrls'] as List).first
                  : null,
              'post_video_url': null,
              'post_author_name': contentJson['authorName'] ?? '',
              'post_author_username': contentJson['authorUsername'] ?? '',
              'post_author_avatar': contentJson['authorAvatar'],
              'post_created_at':
                  contentJson['createdAt'] ?? DateTime.now().toIso8601String(),
              'like_count': contentJson['likesCount'] ?? 0,
              'comment_count': contentJson['commentsCount'] ?? 0,
              'is_verified': false,
              'verification_type': contentJson['verificationType'] ?? 'none',
              'role': contentJson['role'],
            });
          }
        } catch (e) {
          // اگر parse نشد، null می‌ماند
        }
      }
    }

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
      audioUrl: json['audio_url'],
      attachmentType: json['attachment_type'],
      attachmentFileName: json['attachment_file_name'] as String?,
      attachmentMimeType: json['attachment_mime_type'] as String?,
      attachmentSizeBytes: (json['attachment_size_bytes'] as num?)?.toInt(),
      audioTitle: json['audio_title'] as String?,
      audioArtist: json['audio_artist'] as String?,
      audioAlbum: json['audio_album'] as String?,
      duration: json['duration'] as int?,
      senderName: (json['sender_name'] as String?)?.trim().isNotEmpty == true
          ? (json['sender_name'] as String?)?.trim()
          : (profileName.isNotEmpty ? profileName : null),
      senderAvatar:
          (json['sender_avatar'] as String?)?.trim().isNotEmpty == true
              ? (json['sender_avatar'] as String?)?.trim()
              : (profileAvatar != null && profileAvatar.isNotEmpty
                  ? profileAvatar
                  : null),
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
      // ✅ استفاده از متغیر پارس شده
      sharedPostData: parsedSharedPost,
      storyReplyData: _parseStoryReplyData(json['story_reply_data']),
      deletedGlobally: json['deleted_globally'] as bool? ?? false,
      deletedForUserIds: (json['deleted_for_user_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      localImagePath: json['local_image_path'] as String?,
      localFilePath: json['local_file_path'] as String?,
      uploadProgress: json['upload_progress'] != null
          ? (json['upload_progress'] as num).toDouble()
          : null,
      isUploading: json['is_uploading'] as bool? ?? false,
    );
  }

  factory MessageModel.temporary({
    required String tempId,
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? audioUrl,
    String? attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
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
    String? localImagePath,
    String? localFilePath,
    double? uploadProgress,
    bool isUploading = false,
  }) {
    return MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      attachmentUrl: attachmentUrl,
      audioUrl: audioUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      attachmentMimeType: attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes,
      audioTitle: audioTitle,
      audioArtist: audioArtist,
      audioAlbum: audioAlbum,
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
      deletedGlobally: false,
      deletedForUserIds: const [],
      localImagePath: localImagePath,
      localFilePath: localFilePath,
      uploadProgress: uploadProgress,
      isUploading: isUploading,
    );
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    String? attachmentUrl,
    String? audioUrl,
    String? attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
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
    StoryReplyData? storyReplyData,
    bool? isForwarded,
    String? originalSenderId,
    String? forwardedFromSenderName,
    String? originalMessageId,
    bool? deletedGlobally,
    List<String>? deletedForUserIds,
    String? localImagePath,
    String? localFilePath,
    double? uploadProgress,
    bool? isUploading,
  }) {
    final newModel = MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes ?? this.attachmentSizeBytes,
      audioTitle: audioTitle ?? this.audioTitle,
      audioArtist: audioArtist ?? this.audioArtist,
      audioAlbum: audioAlbum ?? this.audioAlbum,
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
      storyReplyData: storyReplyData ?? this.storyReplyData,
      isForwarded: isForwarded ?? this.isForwarded,
      originalSenderId: originalSenderId ?? this.originalSenderId,
      forwardedFromSenderName:
          forwardedFromSenderName ?? this.forwardedFromSenderName,
      originalMessageId: originalMessageId ?? this.originalMessageId,
      deletedGlobally: deletedGlobally ?? this.deletedGlobally,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      localImagePath: localImagePath ?? this.localImagePath,
      localFilePath: localFilePath ?? this.localFilePath,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploading: isUploading ?? this.isUploading,
    );

    // ✅ حفظ ValueNotifier از instance قدیمی به instance جدید
    // این باعث میشه که ValueListenableBuilder listener خودش رو از دست نده
    newModel._statusNotifier.value = _statusNotifier.value;

    // ✅ اگر status fields تغییر کرده، آپدیت کن
    if (isPending != null ||
        isSeen != null ||
        isFailed != null ||
        isSent != null ||
        isDelivered != null) {
      newModel.updateStatus(
        pending: isPending ?? this.isPending,
        seen: isSeen ?? this.isSeen,
        failed: isFailed ?? this.isFailed,
        sent: isSent ?? this.isSent,
        delivered: isDelivered ?? this.isDelivered,
      );
    }

    return newModel;
  }

  /// بررسی اینکه آیا پیام برای کاربر فعلی حذف شده است
  bool isDeletedFor(String currentUserId) {
    return deletedGlobally || deletedForUserIds.contains(currentUserId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'attachment_url': attachmentUrl,
      'audio_url': audioUrl,
      'attachment_type': attachmentType,
      'attachment_file_name': attachmentFileName,
      'attachment_mime_type': attachmentMimeType,
      'attachment_size_bytes': attachmentSizeBytes,
      'audio_title': audioTitle,
      'audio_artist': audioArtist,
      'audio_album': audioAlbum,
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
      'story_reply_data':
          storyReplyData != null ? json.encode(storyReplyData!.toJson()) : null,
      'is_forwarded': isForwarded,
      'original_sender_id': originalSenderId,
      'forwarded_from_sender_name': forwardedFromSenderName,
      'original_message_id': originalMessageId,
      'deleted_globally': deletedGlobally,
      'deleted_for_user_ids': deletedForUserIds,
      'local_image_path': localImagePath,
      'local_file_path': localFilePath,
      'upload_progress': uploadProgress,
      'is_uploading': isUploading,
    };
  }
}
