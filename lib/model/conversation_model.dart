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
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    return ConversationModel(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      participants: json['participants'] != null
          ? List<ConversationParticipantModel>.from(json['participants']
              .map((x) => ConversationParticipantModel.fromJson(x)))
          : [],
      otherUserName: json['otherUserName'],
      otherUserAvatar: json['otherUserAvatar'],
      otherUserId: json['otherUserId'],
      hasUnreadMessages: json['hasUnreadMessages'] ?? false,
      unreadCount: json['unreadCount'] ?? 0, // استفاده از ?? برای مقدار پیش‌فرض
    );
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
    return ConversationParticipantModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      lastReadTime: DateTime.parse(json['last_read_time']),
      isMuted: json['is_muted'] ?? false,
    );
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
