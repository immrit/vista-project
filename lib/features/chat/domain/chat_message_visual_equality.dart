import '../../../model/message_model.dart';

/// Compares [MessageModel] instances for chat list rebuild decisions.
///
/// When two models are visually equal we keep the existing instance reference so
/// Riverpod `select` subscribers do not rebuild.
abstract final class ChatMessageVisualEquality {
  static bool equals(MessageModel? a, MessageModel? b) {
    if (a == null || b == null) return a == b;
    if (a.id != b.id) return false;

    return a.conversationId == b.conversationId &&
        a.senderId == b.senderId &&
        a.content == b.content &&
        a.createdAt == b.createdAt &&
        a.attachmentUrl == b.attachmentUrl &&
        a.audioUrl == b.audioUrl &&
        a.attachmentType == b.attachmentType &&
        a.attachmentFileName == b.attachmentFileName &&
        a.attachmentMimeType == b.attachmentMimeType &&
        a.attachmentSizeBytes == b.attachmentSizeBytes &&
        a.audioTitle == b.audioTitle &&
        a.audioArtist == b.audioArtist &&
        a.audioAlbum == b.audioAlbum &&
        a.mediaGroupId == b.mediaGroupId &&
        a.duration == b.duration &&
        a.isRead == b.isRead &&
        a.isSent == b.isSent &&
        a.isDelivered == b.isDelivered &&
        a.isSeen == b.isSeen &&
        a.senderName == b.senderName &&
        a.senderAvatar == b.senderAvatar &&
        a.isMe == b.isMe &&
        a.replyToMessageId == b.replyToMessageId &&
        a.replyToContent == b.replyToContent &&
        a.replyToSenderName == b.replyToSenderName &&
        a.isPending == b.isPending &&
        a.isFailed == b.isFailed &&
        a.localId == b.localId &&
        a.retryCount == b.retryCount &&
        a.errorMessage == b.errorMessage &&
        a.lastRetryTime == b.lastRetryTime &&
        a.isForwarded == b.isForwarded &&
        a.originalSenderId == b.originalSenderId &&
        a.forwardedFromSenderName == b.forwardedFromSenderName &&
        a.originalMessageId == b.originalMessageId &&
        a.messageType == b.messageType &&
        a.deletedGlobally == b.deletedGlobally &&
        _listEquals(a.deletedForUserIds, b.deletedForUserIds) &&
        a.localImagePath == b.localImagePath &&
        a.localFilePath == b.localFilePath &&
        a.uploadProgress == b.uploadProgress &&
        a.isUploading == b.isUploading &&
        _mapEquals(a.reactions, b.reactions) &&
        _sharedPostEquals(a.sharedPostData, b.sharedPostData) &&
        _storyReplyEquals(a.storyReplyData, b.storyReplyData);
  }

  /// True when only delivery/status fields differ — safe to patch in-place.
  static bool isDeliveryOnlyChange(MessageModel existing, MessageModel incoming) {
    if (identical(existing, incoming)) return false;
    if (existing.id != incoming.id) return false;
    if (equals(existing, incoming)) return false;
    return contentEquals(existing, incoming) &&
        deliveryFieldsDiffer(existing, incoming);
  }

  static void patchDeliveryStatus(MessageModel target, MessageModel source) {
    target.updateStatus(
      pending: source.isPending,
      seen: source.isSeen,
      read: source.isRead,
      failed: source.isFailed,
      sent: source.isSent,
      delivered: source.isDelivered,
    );
  }

  static bool contentEquals(MessageModel a, MessageModel b) {
    if (a.id != b.id) return false;
    return a.conversationId == b.conversationId &&
        a.senderId == b.senderId &&
        a.content == b.content &&
        a.createdAt == b.createdAt &&
        a.attachmentUrl == b.attachmentUrl &&
        a.audioUrl == b.audioUrl &&
        a.attachmentType == b.attachmentType &&
        a.attachmentFileName == b.attachmentFileName &&
        a.attachmentMimeType == b.attachmentMimeType &&
        a.attachmentSizeBytes == b.attachmentSizeBytes &&
        a.audioTitle == b.audioTitle &&
        a.audioArtist == b.audioArtist &&
        a.audioAlbum == b.audioAlbum &&
        a.mediaGroupId == b.mediaGroupId &&
        a.duration == b.duration &&
        a.senderName == b.senderName &&
        a.senderAvatar == b.senderAvatar &&
        a.isMe == b.isMe &&
        a.replyToMessageId == b.replyToMessageId &&
        a.replyToContent == b.replyToContent &&
        a.replyToSenderName == b.replyToSenderName &&
        a.localId == b.localId &&
        a.retryCount == b.retryCount &&
        a.errorMessage == b.errorMessage &&
        a.lastRetryTime == b.lastRetryTime &&
        a.isForwarded == b.isForwarded &&
        a.originalSenderId == b.originalSenderId &&
        a.forwardedFromSenderName == b.forwardedFromSenderName &&
        a.originalMessageId == b.originalMessageId &&
        a.messageType == b.messageType &&
        a.deletedGlobally == b.deletedGlobally &&
        _listEquals(a.deletedForUserIds, b.deletedForUserIds) &&
        a.localImagePath == b.localImagePath &&
        a.localFilePath == b.localFilePath &&
        a.uploadProgress == b.uploadProgress &&
        a.isUploading == b.isUploading &&
        _mapEquals(a.reactions, b.reactions) &&
        _sharedPostEquals(a.sharedPostData, b.sharedPostData) &&
        _storyReplyEquals(a.storyReplyData, b.storyReplyData);
  }

  static bool deliveryFieldsDiffer(MessageModel a, MessageModel b) {
    return a.isRead != b.isRead ||
        a.isSent != b.isSent ||
        a.isDelivered != b.isDelivered ||
        a.isSeen != b.isSeen ||
        a.isPending != b.isPending ||
        a.isFailed != b.isFailed;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !_listEquals(entry.value, other)) return false;
    }
    return true;
  }

  static bool _sharedPostEquals(SharedPostData? a, SharedPostData? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.postId == b.postId &&
        a.postContent == b.postContent &&
        a.postImageUrl == b.postImageUrl &&
        a.postVideoUrl == b.postVideoUrl &&
        a.postAuthorName == b.postAuthorName &&
        a.postAuthorUsername == b.postAuthorUsername &&
        a.postAuthorAvatar == b.postAuthorAvatar &&
        a.postCreatedAt == b.postCreatedAt &&
        a.likeCount == b.likeCount &&
        a.commentCount == b.commentCount &&
        a.isVerified == b.isVerified &&
        a.verificationType == b.verificationType &&
        a.role == b.role;
  }

  static bool _storyReplyEquals(StoryReplyData? a, StoryReplyData? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.storyId == b.storyId &&
        a.storyOwnerId == b.storyOwnerId &&
        a.storyOwnerUsername == b.storyOwnerUsername &&
        a.storyThumbnailUrl == b.storyThumbnailUrl &&
        a.storyMediaType == b.storyMediaType &&
        a.storyCreatedAt == b.storyCreatedAt &&
        a.replyKind == b.replyKind &&
        a.answerText == b.answerText &&
        a.questionText == b.questionText;
  }
}
