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

              // Extract profile info if available
              final profiles = participantData['profiles'];
              if (profiles != null) {
                otherUserName = profiles['username'] as String?;
                otherUserAvatar = profiles['avatar_url'] as String?;
              } else {
                // No profile info available - will be enriched later
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
      );
    } catch (e) {
      print('❌ خطا در تبدیل JSON به ConversationModel: $e');
      print('📄 JSON داده: $json');
      rethrow;
    }
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
      'is_muted': isMuted, // اضافه کردن isMuted به JSON
      'is_archived': isArchived, // اضافه کردن وضعیت بایگانی به JSON
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
    bool? isMuted, // اضافه کردن پارامتر isMuted
    bool? isArchived,
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
      isMuted: isMuted ?? this.isMuted, // استفاده از isMuted
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// Format last message for display (handle encrypted messages)
  String? get formattedLastMessage {
    if (lastMessage == null || lastMessage!.isEmpty) return null;

    // Check if message is encrypted
    if (lastMessage!.startsWith('e2ee:v1:')) {
      return '🔒 پیام رمزگذاری شده';
    }

    return lastMessage;
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
      unreadCount: 0, // اضافه کردن مقدار پیش‌فرض
      isPinned: false,
      isMuted: false, // مقدار پیش‌فرض برای isMuted
      isArchived: false,
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
