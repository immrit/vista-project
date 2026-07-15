// lib/features/chat/repositories/chat_repository.dart
//
// Interface اصلی برای Repository چت
// Go backend chat repository interface

import '../../../model/message_model.dart';
import '../../../model/conversation_model.dart';
import '../domain/message_payload.dart';
import '../services/sse_manager.dart';

export '../services/sse_manager.dart' show SseConnectionState;

/// نتیجه عملیات با قابلیت نمایش خطای کاربرپسند
class ChatResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const ChatResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory ChatResult.success(T data) => ChatResult._(
        data: data,
        isSuccess: true,
      );

  factory ChatResult.failure(String error) => ChatResult._(
        error: error,
        isSuccess: false,
      );

  R fold<R>(R Function(T data) onSuccess, R Function(String error) onFailure) {
    if (isSuccess) {
      return onSuccess(data as T);
    } else {
      return onFailure(error!);
    }
  }
}

enum LoadingState {
  initial,
  loading,
  loaded,
  loadingMore,
  error,
}

abstract class ChatRepository {
  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<ChatResult<List<ConversationModel>>> getConversations();

  Stream<List<ConversationModel>> watchConversations();

  Future<ChatResult<ConversationModel>> createConversation(String otherUserId,
      {bool isSecret = false});

  Future<ChatResult<void>> deleteConversation(String conversationId);

  Future<ChatResult<void>> toggleArchiveConversation(String conversationId);

  Future<ChatResult<void>> togglePinConversation(String conversationId);

  Future<ChatResult<void>> toggleMuteConversation(String conversationId);

  Future<ChatResult<void>> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  });

  Future<ChatResult<void>> clearConversation(
    String conversationId, {
    bool forEveryone = false,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES
  // ═══════════════════════════════════════════════════════════════════

  Future<ChatResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  });

  Stream<List<MessageModel>> watchMessages(String conversationId, {int? limit});

  Future<ChatResult<MessageModel>> sendMessage(MessagePayload payload);

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
  });

  Future<ChatResult<void>> updateUploadProgress(
      String localId, double progress);

  Future<ChatResult<void>> markUploadSucceeded(
      String localId, MessageModel serverMessage);

  Future<ChatResult<void>> markUploadFailed(
    String localId, {
    String? errorMessage,
  });

  Future<ChatResult<void>> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  });

  Future<ChatResult<void>> editMessage(String messageId, String newContent);

  Future<ChatResult<List<MessageModel>>> searchMessages(
    String conversationId,
    String query,
  );

  Future<ChatResult<List<MessageModel>>> loadMoreMessages({
    required String conversationId,
    required DateTime oldestMessageDate,
    int limit = 50,
  });

  /// Server-backed pagination state for [loadMoreMessages].
  ///
  /// The cursor is intentionally owned by the repository so UI code cannot
  /// accidentally recreate a timestamp-only cursor and introduce gaps when
  /// multiple messages share the same creation time.
  bool hasMoreMessages(String conversationId);

  Future<ChatResult<void>> acceptMessageRequest(String conversationId);

  Future<ChatResult<void>> rejectMessageRequest(String conversationId);

  // ═══════════════════════════════════════════════════════════════════
  // 😀 REACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  });

  Stream<Map<String, List<String>>> watchReactions(String messageId);

  // ═══════════════════════════════════════════════════════════════════
  // ⌨️ TYPING
  // ═══════════════════════════════════════════════════════════════════

  Future<void> sendTypingIndicator(String conversationId);

  Stream<bool> watchTypingStatus(String conversationId, String userId);

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SYNC & REFRESH
  // ═══════════════════════════════════════════════════════════════════

  Future<void> refreshConversations();

  Future<void> refreshMessages(String conversationId);

  Future<void> syncPendingMessages();

  /// ارسال مجدد خودکار پیام‌های خروجیِ ناموفق (isFailed) — پس از برقراری
  /// دوباره‌ی اتصال فراخوانی می‌شود.
  Future<void> resendFailedMessages();

  Future<void> cacheConversationProfile({
    required String conversationId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════

  void dispose();

  Future<void> clearAllCache();

  Future<void> clearConversationCache(String conversationId);

  Future<void> resetUnreadCount(String conversationId);

  Future<bool> isUserBlocked(String userId);

  Future<void> unblockUser(String userId);

  Future<bool> isCurrentUserBlockedBy(String userId);

  void setActiveConversation(String? conversationId);

  Future<void> handleNotificationMessage(Map<String, dynamic> payload);

  /// Go backend realtime connection status.
  Stream<SseConnectionState> get realtimeStatus;

  Future<void> markMessagesAsSeen(String conversationId);
}
