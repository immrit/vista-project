class ChannelMessageModel {
  final String id;
  final String channelId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final int viewsCount;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final String? imageUrl;
  final String messageType;
  final DateTime? updatedAt;
  final bool isEdited;
  final bool isDeleted;
  final String? deletedBy;
  final String? senderName;
  final String? senderAvatar;
  final bool isMe;

  ChannelMessageModel({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.viewsCount = 0,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.imageUrl,
    this.messageType = 'text',
    this.updatedAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.deletedBy,
    this.senderName,
    this.senderAvatar,
    required this.isMe,
  });

  factory ChannelMessageModel.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    print('Parsing message JSON: $json'); // Debug log
    print('Is Deleted from JSON: ${json['is_deleted']}');
    print('Is Edited from JSON: ${json['is_edited']}');

    return ChannelMessageModel(
      id: json['id'],
      channelId: json['channel_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      viewsCount: json['views_count'] ?? 0,
      replyToMessageId: json['reply_to_message_id'],
      replyToContent: json['reply_to_content'],
      replyToSenderName: json['reply_to_sender_name'],
      imageUrl: json['image_url'],
      messageType: json['message_type'] ?? 'text',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isEdited: json['is_edited'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      deletedBy: json['deleted_by'],
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
      isMe: currentUserId != null && json['sender_id'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel_id': channelId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'views_count': viewsCount,
      'reply_to_message_id': replyToMessageId,
      'reply_to_content': replyToContent,
      'reply_to_sender_name': replyToSenderName,
      'image_url': imageUrl,
      'message_type': messageType,
      'updated_at': updatedAt?.toIso8601String(),
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'deleted_by': deletedBy,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
    };
  }

  ChannelMessageModel copyWith({
    String? id,
    String? channelId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    String? attachmentUrl,
    String? attachmentType,
    int? viewsCount,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? imageUrl,
    String? messageType,
    DateTime? updatedAt,
    bool? isEdited,
    bool? isDeleted,
    String? deletedBy,
    String? senderName,
    String? senderAvatar,
    bool? isMe,
  }) {
    return ChannelMessageModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      viewsCount: viewsCount ?? this.viewsCount,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      imageUrl: imageUrl ?? this.imageUrl,
      messageType: messageType ?? this.messageType,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      isMe: isMe ?? this.isMe,
    );
  }

  static ChannelMessageModel empty() {
    return ChannelMessageModel(
      id: '',
      channelId: '',
      senderId: '',
      content: '',
      createdAt: DateTime.now(),
      isMe: false,
    );
  }
}
