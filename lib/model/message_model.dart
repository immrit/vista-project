class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
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
  final String? localId;
  final int retryCount; // اضافه کنید

  // Typing indicators برای نشان دادن کاربران در حال تایپ
  final Map<String, DateTime>? typingUsers;

  // ری‌اکشن‌های پیام
  final List<dynamic>? reactions;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt, // Add this parameter
    this.attachmentUrl,
    this.attachmentType,
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
    this.localId,
    this.retryCount = 0, // مقدار پیش‌فرض
    this.typingUsers,
    this.reactions,
  });

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

  factory MessageModel.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    String conversationId = json['conversation_id'] ??
        json['conversations_id'] ??
        ''; // Check this too!

    // Note: waveform_data is no longer used in messages

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
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
      isMe: json['sender_id'] == currentUserId,
      replyToMessageId: json['reply_to_message_id'],
      replyToContent: json['reply_to_content'],
      replyToSenderName: json['reply_to_sender_name'],
      localId: json['local_id'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
      isPending: json['is_pending'] as bool? ?? false,
      typingUsers: json['typing_users'] != null
          ? Map<String, DateTime>.from(json['typing_users'])
          : null,
      reactions: json['reactions'],
    );
  }

  factory MessageModel.temporary({
    required String tempId,
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    int? duration,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? senderName,
    String? senderAvatar,
    DateTime? createdAt,
    isRead = false,
    isSent = true,
    int retryCount = 0,
  }) {
    return MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
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
    String? localId,
    int? retryCount, // اضافه کنید
    Map<String, DateTime>? typingUsers,
    List<dynamic>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
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
      localId: localId ?? this.localId,
      retryCount: retryCount ?? this.retryCount,
      typingUsers: typingUsers ?? this.typingUsers,
      reactions: reactions ?? this.reactions,
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
      'local_id': localId,
      'retry_count': retryCount,
      'typing_users': typingUsers,
      'reactions': reactions,
    };
  }
}
