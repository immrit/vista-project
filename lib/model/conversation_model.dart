import '../security/logging_utility.dart';
import '../services/telegram_read_receipt_service.dart';

class ConversationModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<ConversationParticipantModel> participants;

  // اطلاعات اضافی که از ترکیب با اطلاعات کاربران به دست می‌آید
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? otherUserId;
  final bool hasUnreadMessages;
  final int unreadCount; // تعداد پیام‌های خوانده‌نشده
  final bool isPinned;
  final bool isMuted; // اضافه کردن فیلد isMuted
  final bool isArchived; // فیلد جدید برای وضعیت بایگانی
  final bool? allowProfileZoom; // ✅ اجازه بزرگنمایی عکس پروفایل کاربر مقابل
  // ✅ اطلاعات پروفایل کاربر مقابل برای صفحه جزئیات چت
  final String? otherUserBio; // بیوگرافی کاربر مقابل
  final DateTime? otherUserCreatedAt; // تاریخ عضویت کاربر مقابل
  final bool? isBlocked; // وضعیت بلاک بودن کاربر مقابل
  final bool? isVerified; // وضعیت تایید شده بودن کاربر مقابل
  final String?
      lastMessageType; // نوع آخرین پیام: text, voice, image, video, post, file, sticker
  final bool isLastMessageFromMe; // آیا آخرین پیام از من است؟
  final String? lastMessageSenderId; // شناسه فرستنده آخرین پیام
  final MessageDeliveryStatus
      lastMessageDeliveryStatus; // وضعیت تحویل آخرین پیام

  ConversationModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.participants = const [],
    this.otherUserName, // اطمینان از وجود این فیلد
    this.otherUserAvatar,
    this.otherUserId,
    this.hasUnreadMessages = false,
    this.unreadCount = 0, // مقدار پیش‌فرض 0 برای جلوگیری از null
    this.isPinned = false,
    this.isMuted = false, // مقدار پیش‌فرض برای isMuted
    this.isArchived = false, // مقدار پیش‌فرض برای بایگانی
    this.lastMessageType, // نوع آخرین پیام
    this.isLastMessageFromMe = false, // آیا آخرین پیام از من است
    this.lastMessageSenderId, // شناسه فرستنده آخرین پیام
    this.lastMessageDeliveryStatus =
        MessageDeliveryStatus.sent, // وضعیت تحویل آخرین پیام
    this.allowProfileZoom, // ✅ اجازه بزرگنمایی عکس پروفایل
    this.otherUserBio, // ✅ بیوگرافی کاربر مقابل
    this.otherUserCreatedAt, // ✅ تاریخ عضویت کاربر مقابل
    this.isBlocked, // ✅ وضعیت بلاک بودن
    this.isVerified, // ✅ وضعیت تایید شده بودن
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    try {
      // بررسی وجود فیلدهای اجباری
      if (json['id'] == null) {
        throw Exception('فیلد id در JSON موجود نیست');
      }

      if (json['created_at'] == null) {
        throw Exception('فیلد created_at در JSON موجود نیست');
      }

      if (json['updated_at'] == null) {
        throw Exception('فیلد updated_at در JSON موجود نیست');
      }

      // Parse participants and extract other user info
      List<ConversationParticipantModel> participants = [];
      String? otherUserName;
      String? otherUserAvatar;
      String? otherUserId;

      final participantsData =
          json['conversation_participants'] ?? json['participants'];
      if (participantsData != null) {
        participants = List<ConversationParticipantModel>.from(participantsData
            .map((x) => ConversationParticipantModel.fromJson(x)));

        // Find other user info if currentUserId is provided
        if (currentUserId != null) {
          for (final participantData in participantsData) {
            final participantUserId = participantData['user_id'] as String?;
            if (participantUserId != null &&
                participantUserId != currentUserId) {
              otherUserId = participantUserId;

              // Extract profile info if available - prioritize cached data
              final profiles = participantData['profiles'];
              if (profiles != null) {
                otherUserName = profiles['username'] as String?;
                otherUserAvatar = profiles['avatar_url'] as String?;
              } else {
                // No profile info available - will be enriched by ProfileService later
                otherUserName = null;
                otherUserAvatar = null;
              }
              break;
            }
          }
        }
      }

      return ConversationModel(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        lastMessage: json['last_message'] as String?,
        lastMessageTime: json['last_message_time'] != null
            ? DateTime.parse(json['last_message_time'] as String)
            : null,
        participants: participants,
        otherUserName:
            otherUserName ?? json['otherUserName'] as String? ?? 'کاربر ناشناس',
        otherUserAvatar: otherUserAvatar ?? json['otherUserAvatar'] as String?,
        otherUserId: otherUserId ?? json['otherUserId'] as String?,
        hasUnreadMessages: json['hasUnreadMessages'] ?? false,
        unreadCount: json['unreadCount'] ?? 0,
        isPinned: json['is_pinned'] ?? false,
        isMuted: json['is_muted'] ?? false,
        isArchived: json['is_archived'] ?? false,
        lastMessageType: json['last_message_type'] as String?,
        isLastMessageFromMe: json['is_last_message_from_me'] ?? false,
        lastMessageSenderId: json['last_message_sender_id'] as String?,
        lastMessageDeliveryStatus: _parseDeliveryStatus(json),
        allowProfileZoom: json['allow_profile_zoom'] as bool?,
        otherUserBio: json['other_user_bio'] as String?,
        otherUserCreatedAt: json['other_user_created_at'] != null
            ? DateTime.parse(json['other_user_created_at'] as String)
            : null,
        isBlocked: json['is_blocked'] as bool?,
        isVerified: json['is_verified'] as bool?,
      );
    } catch (e) {
      logInfo('❌ خطا در تبدیل JSON به ConversationModel: $e');
      logInfo('📄 JSON داده: $json');
      rethrow;
    }
  }

  /// پارس کردن وضعیت تحویل از JSON
  static MessageDeliveryStatus _parseDeliveryStatus(Map<String, dynamic> json) {
    // اول بررسی فیلد مستقیم
    final statusStr = json['last_message_delivery_status'] as String?;
    if (statusStr != null) {
      switch (statusStr) {
        case 'pending':
          return MessageDeliveryStatus.pending;
        case 'sent':
          return MessageDeliveryStatus.sent;
        case 'delivered':
          return MessageDeliveryStatus.delivered;
        case 'read':
          return MessageDeliveryStatus.read;
        case 'failed':
          return MessageDeliveryStatus.failed;
      }
    }

    // بررسی فیلدهای is_sent، is_delivered، is_seen از آخرین پیام
    final isSeen = json['last_message_is_seen'] as bool? ?? false;
    final isDelivered = json['last_message_is_delivered'] as bool? ?? false;
    final isSent = json['last_message_is_sent'] as bool? ?? true;

    if (isSeen) return MessageDeliveryStatus.read;
    if (isDelivered) return MessageDeliveryStatus.delivered;
    if (isSent) return MessageDeliveryStatus.sent;
    return MessageDeliveryStatus.pending;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'otherUserId': otherUserId,
      'hasUnreadMessages': hasUnreadMessages,
      'unreadCount': unreadCount,
      'is_pinned': isPinned,
      'is_muted': isMuted,
      'is_archived': isArchived,
      'last_message_type': lastMessageType,
      'is_last_message_from_me': isLastMessageFromMe,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_delivery_status': lastMessageDeliveryStatus.name,
      'allow_profile_zoom': allowProfileZoom,
      'other_user_bio': otherUserBio,
      'other_user_created_at': otherUserCreatedAt?.toIso8601String(),
      'is_blocked': isBlocked,
      'is_verified': isVerified,
    };
  }

  ConversationModel copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    List<ConversationParticipantModel>? participants,
    String? otherUserName,
    String? otherUserAvatar,
    String? otherUserId,
    bool? hasUnreadMessages,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    String? lastMessageType,
    bool? isLastMessageFromMe,
    String? lastMessageSenderId,
    MessageDeliveryStatus? lastMessageDeliveryStatus,
    bool? allowProfileZoom,
    String? otherUserBio,
    DateTime? otherUserCreatedAt,
    bool? isBlocked,
    bool? isVerified,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      participants: participants ?? this.participants,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      otherUserId: otherUserId ?? this.otherUserId,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageDeliveryStatus:
          lastMessageDeliveryStatus ?? this.lastMessageDeliveryStatus,
      allowProfileZoom: allowProfileZoom ?? this.allowProfileZoom,
      otherUserBio: otherUserBio ?? this.otherUserBio,
      otherUserCreatedAt: otherUserCreatedAt ?? this.otherUserCreatedAt,
      isBlocked: isBlocked ?? this.isBlocked,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Format last message for display (handle encrypted messages and message types)
  String? get formattedLastMessage {
    // اول نوع پیام رو چک کن
    if (lastMessageType != null && lastMessageType != 'text') {
      return _getMessageTypePreview(lastMessageType!);
    }

    if (lastMessage == null || lastMessage!.isEmpty) return null;

    // Check if message is encrypted
    if (lastMessage!.startsWith('e2ee:v1:')) {
      return '🔒 پیام رمزگذاری شده';
    }

    return lastMessage;
  }

  /// نمایش پیش‌نمایش بر اساس نوع پیام
  String _getMessageTypePreview(String type) {
    switch (type.toLowerCase()) {
      case 'voice':
      case 'audio':
        return '🎤 پیام صوتی';
      case 'image':
      case 'photo':
        return '📷 تصویر';
      case 'video':
        return '🎬 ویدیو';
      case 'post':
      case 'shared_post':
        return '📮 پست';
      case 'file':
      case 'document':
        return '📎 فایل';
      case 'sticker':
        return '😀 استیکر';
      case 'gif':
        return '🎞️ گیف';
      case 'location':
        return '📍 موقعیت مکانی';
      case 'contact':
        return '👤 مخاطب';
      case 'poll':
        return '📊 نظرسنجی';
      case 'link':
        return '🔗 لینک';
      case 'reply':
        // اگر reply بود، متن اصلی رو نمایش بده
        return lastMessage ?? '↩️ پاسخ';
      case 'forward':
        return '↗️ فوروارد شده';
      default:
        return lastMessage ?? 'پیام';
    }
  }

  static ConversationModel empty() {
    return ConversationModel(
      id: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      otherUserName: '',
      otherUserAvatar: null,
      otherUserId: '',
      lastMessage: null,
      lastMessageTime: null,
      hasUnreadMessages: false,
      unreadCount: 0,
      isPinned: false,
      isMuted: false,
      isArchived: false,
      lastMessageType: null,
      isLastMessageFromMe: false,
      lastMessageSenderId: null,
      lastMessageDeliveryStatus: MessageDeliveryStatus.sent,
    );
  }
}

class ConversationParticipantModel {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastReadTime; // nullable شد
  final bool isMuted;

  ConversationParticipantModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.createdAt,
    this.lastReadTime, // nullable
    this.isMuted = false,
  });

  factory ConversationParticipantModel.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      throw Exception('فیلد id در ConversationParticipantModel موجود نیست');
    }
    if (json['conversation_id'] == null) {
      throw Exception(
          'فیلد conversation_id در ConversationParticipantModel موجود نیست');
    }
    if (json['user_id'] == null) {
      throw Exception(
          'فیلد user_id در ConversationParticipantModel موجود نیست');
    }
    if (json['created_at'] == null) {
      throw Exception(
          'فیلد created_at در ConversationParticipantModel موجود نیست');
    }
    // last_read_time ممکن است null باشد
    return ConversationParticipantModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastReadTime: json['last_read_time'] != null
          ? DateTime.tryParse(json['last_read_time'] as String)
          : null,
      isMuted: json['is_muted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_read_time': lastReadTime?.toIso8601String(),
      'is_muted': isMuted,
    };
  }
}
