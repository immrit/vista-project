class DirectMessage {
  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String messageType;
  final String? mediaUrl;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.messageType,
    this.mediaUrl,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      messageType: json['message_type'] ?? 'text',
      mediaUrl: json['media_url'],
    );
  }
}
