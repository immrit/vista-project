class SendMessageParams {
  final String conversationId;
  final String content;
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
  final String? replyToKind;
  final String? recipientPublicKey;

  const SendMessageParams({
    required this.conversationId,
    required this.content,
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
    this.replyToKind,
    this.recipientPublicKey,
  });
}
