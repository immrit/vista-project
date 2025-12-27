class SendMessageParams {
  final String conversationId;
  final String content;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final int? duration;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;

  const SendMessageParams({
    required this.conversationId,
    required this.content,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.duration,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
  });
}
