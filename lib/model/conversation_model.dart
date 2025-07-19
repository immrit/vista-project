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

      return ConversationModel(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        lastMessage: json['last_message'] as String?,
        lastMessageTime: json['last_message_time'] != null
            ? DateTime.parse(json['last_message_time'] as String)
            : null,
        participants: json['participants'] != null
            ? List<ConversationParticipantModel>.from(json['participants']
                .map((x) => ConversationParticipantModel.fromJson(x)))
            : [],
        otherUserName: json['otherUserName'] as String?,
        otherUserAvatar: json['otherUserAvatar'] as String?,
        otherUserId: json['otherUserId'] as String?,
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
  final DateTime lastReadTime;
  final bool isMuted;

  ConversationParticipantModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.createdAt,
    required this.lastReadTime,
    this.isMuted = false,
  });

  factory ConversationParticipantModel.fromJson(Map<String, dynamic> json) {
    try {
      // بررسی وجود فیلدهای اجباری
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

      if (json['last_read_time'] == null) {
        throw Exception(
            'فیلد last_read_time در ConversationParticipantModel موجود نیست');
      }

      return ConversationParticipantModel(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        userId: json['user_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastReadTime: DateTime.parse(json['last_read_time'] as String),
        isMuted: json['is_muted'] ?? false,
      );
    } catch (e) {
      print('❌ خطا در تبدیل JSON به ConversationParticipantModel: $e');
      print('📄 JSON داده: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_read_time': lastReadTime.toIso8601String(),
      'is_muted': isMuted,
    };
  }
}
