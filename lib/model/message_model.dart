class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final bool isEdited;
  final DateTime? editedAt;
  final String? attachmentUrl;
  final String? attachmentType;

  // اطلاعات اضافی برای نمایش
  final String? senderName;
  final String? senderAvatar;
  final bool isMine;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.isEdited = false,
    this.editedAt,
    this.attachmentUrl,
    this.attachmentType,
    this.senderName,
    this.senderAvatar,
    this.isMine = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    String conversationId =
        json['conversation_id'] ?? json['conversations_id'] ?? '';

    return MessageModel(
      id: json['id'],
      conversationId: conversationId,
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      isEdited: json['is_edited'] ?? false,
      editedAt:
          json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      isMine: json['sender_id'] == currentUserId,
    );
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    bool? isEdited,
    DateTime? editedAt,
    String? attachmentUrl,
    String? attachmentType,
    String? senderName,
    String? senderAvatar,
    bool? isMine,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMine: isMine ?? this.isMine,
    );
  }
}
