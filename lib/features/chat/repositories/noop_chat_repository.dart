// lib/features/chat/repositories/noop_chat_repository.dart
//
// No-op chat repository for disabled states.

import '../../../model/conversation_model.dart';
import '../../../model/message_model.dart';
import '../domain/message_payload.dart';
import 'chat_repository.dart';

class NoopChatRepository implements ChatRepository {
  ChatResult<T> _failure<T>() => ChatResult.failure('Chat backend unavailable');

  @override
  Future<ChatResult<List<ConversationModel>>> getConversations() async =>
      ChatResult.success(const []);

  @override
  Stream<List<ConversationModel>> watchConversations() =>
      Stream.value(const []);

  @override
  Future<ChatResult<ConversationModel>> createConversation(
          String otherUserId) async =>
      _failure();

  @override
  Future<ChatResult<void>> deleteConversation(String conversationId) async =>
      _failure();

  @override
  Future<ChatResult<void>> toggleArchiveConversation(
          String conversationId) async =>
      _failure();

  @override
  Future<ChatResult<void>> togglePinConversation(String conversationId) async =>
      _failure();

  @override
  Future<ChatResult<void>> toggleMuteConversation(
          String conversationId) async =>
      _failure();

  @override
  Future<ChatResult<void>> clearConversation(String conversationId,
          {bool forEveryone = false}) async =>
      _failure();

  @override
  Future<ChatResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  }) async =>
      ChatResult.success(const []);

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) =>
      Stream.value(const []);

  @override
  Future<ChatResult<MessageModel>> sendMessage(MessagePayload payload) async =>
      _failure();

  @override
  Future<ChatResult<MessageModel>> createPendingMessage({
    required String conversationId,
    required String content,
    required String localId,
    required String attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
    String? localFilePath,
    int? duration,
    String? mediaGroupId,
  }) async =>
      _failure();

  @override
  Future<ChatResult<void>> updateUploadProgress(
          String localId, double progress) async =>
      _failure();

  @override
  Future<ChatResult<void>> markUploadSucceeded(
          String localId, MessageModel serverMessage) async =>
      _failure();

  @override
  Future<ChatResult<void>> markUploadFailed(String localId,
          {String? errorMessage}) async =>
      _failure();

  @override
  Future<ChatResult<void>> deleteMessage(String messageId,
          {bool forEveryone = false}) async =>
      _failure();

  @override
  Future<ChatResult<void>> editMessage(
          String messageId, String newContent) async =>
      _failure();

  @override
  Future<ChatResult<List<MessageModel>>> searchMessages(
          String conversationId, String query) async =>
      ChatResult.success(const []);

  @override
  Future<ChatResult<List<MessageModel>>> loadMoreMessages({
    required String conversationId,
    required DateTime oldestMessageDate,
    int limit = 50,
  }) async =>
      ChatResult.success(const []);

  @override
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async =>
      _failure();

  @override
  Stream<Map<String, List<String>>> watchReactions(String messageId) =>
      Stream.value(const {});

  @override
  Future<void> sendTypingIndicator(String conversationId) async {}

  @override
  Stream<bool> watchTypingStatus(String conversationId, String userId) =>
      Stream.value(false);

  @override
  Future<void> refreshConversations() async {}

  @override
  Future<void> refreshMessages(String conversationId) async {}

  @override
  Future<void> syncPendingMessages() async {}

  @override
  void dispose() {}

  @override
  Future<void> clearAllCache() async {}

  @override
  Future<void> clearConversationCache(String conversationId) async {}

  @override
  Future<void> resetUnreadCount(String conversationId) async {}

  @override
  Future<bool> isUserBlocked(String userId) async => false;

  @override
  Future<void> unblockUser(String userId) async {}

  @override
  Future<bool> isCurrentUserBlockedBy(String userId) async => false;

  @override
  void setActiveConversation(String? conversationId) {}

  @override
  Future<void> handleNotificationMessage(Map<String, dynamic> payload) async {}

  @override
  Stream<SseConnectionState> get realtimeStatus =>
      Stream.value(SseConnectionState.disconnected);

  @override
  Future<void> markMessagesAsSeen(String conversationId) async {}
}
