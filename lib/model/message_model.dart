class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final bool isRead;
  final bool isSent;
  final String? senderName;
  final String? senderAvatar;
  final bool isMe;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isPending;
  final String? localId;
  final int retryCount; // اضافه کنید

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt, // Add this parameter
    this.attachmentUrl,
    this.attachmentType,
    this.isRead = false,
    this.isSent = true,
    this.senderName,
    this.senderAvatar,
    required this.isMe,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.isPending = false,
    this.localId,
    this.retryCount = 0, // مقدار پیش‌فرض
  });

  factory MessageModel.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    String conversationId = json['conversation_id'] ??
        json['conversations_id'] ??
        ''; // Check this too!

    return MessageModel(
      id: json['id'],
      conversationId: conversationId,
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      isSent: json['is_sent'] ?? true,
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
      isMe: json['sender_id'] == currentUserId,
      replyToMessageId: json['reply_to_message_id'],
      replyToContent: json['reply_to_content'],
      replyToSenderName: json['reply_to_sender_name'],
    );
  }

  factory MessageModel.temporary({
    required String tempId,
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? senderName,
    String? senderAvatar,
    DateTime? createdAt,
    isRead = false,
    isSent = true,
    int retryCount = 0, // اضافه کنید
  }) {
    return MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
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
    String? senderName,
    String? senderAvatar,
    bool? isMe,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool? isPending,
    String? localId,
    int? retryCount, // اضافه کنید
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
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMe: isMe ?? this.isMe,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isPending: isPending ?? this.isPending,
      localId: localId ?? this.localId,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
