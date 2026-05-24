// lib/features/chat/domain/message_payload.dart

class MessagePayload {
  final String conversationId;
  final String content;
  final String? id; // برای Optimistic UI (UUID v4)
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioAlbum;
  final int? duration;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final String? mediaGroupId;
  final String? recipientPublicKey; // برای E2EE

  MessagePayload({
    required this.conversationId,
    required this.content,
    this.id,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
    this.audioTitle,
    this.audioArtist,
    this.audioAlbum,
    this.duration,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.mediaGroupId,
    this.recipientPublicKey,
  });
}
