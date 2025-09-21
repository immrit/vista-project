import '../model/message_model.dart';
import 'unified_message_cache_service.dart';

/// Wrapper for MessageCacheService that uses unified services
class MessageCacheService {
  static final MessageCacheService _instance = MessageCacheService._internal();
  factory MessageCacheService() => _instance;
  MessageCacheService._internal();

  final UnifiedMessageCacheService _unifiedService =
      UnifiedMessageCacheService();

  /// Initialize the cache service
  Future<void> initialize() async {
    await _unifiedService.initialize();
  }

  /// Cache a message
  Future<void> cacheMessage(MessageModel message, String userId) async {
    return await _unifiedService.cacheMessage(message, userId);
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>> getCachedMessages(
      String conversationId, String userId) async {
    return await _unifiedService.getCachedMessages(conversationId, userId);
  }

  /// Get conversation messages (alias for getCachedMessages)
  Future<List<MessageModel>> getConversationMessages(
      String conversationId, String userId,
      {int? limit}) async {
    final messages =
        await _unifiedService.getCachedMessages(conversationId, userId);
    if (limit != null && limit > 0) {
      return messages.take(limit).toList();
    }
    return messages;
  }

  /// Get a specific message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId, String userId) async {
    return await _unifiedService.getMessage(conversationId, messageId, userId);
  }

  /// Update a message
  Future<void> updateMessage(MessageModel message, String userId) async {
    return await _unifiedService.updateMessage(message, userId);
  }

  /// Clear messages for a conversation
  Future<void> clearConversationMessages(
      String conversationId, String userId) async {
    return await _unifiedService.clearConversationMessages(
        conversationId, userId);
  }

  /// Clear a specific message
  Future<void> clearMessage(
      String conversationId, String messageId, String userId) async {
    return await _unifiedService.clearMessage(
        conversationId, messageId, userId);
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    return await _unifiedService.clearAllCache();
  }

  /// Delete messages older than specified date
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    return await _unifiedService.deleteMessagesOlderThan(date);
  }

  /// Count unread messages
  Future<int> countUnreadMessages(String conversationId) async {
    return await _unifiedService.countUnreadMessages(conversationId);
  }

  /// Perform transaction
  Future<void> performTransaction(Future<void> Function() action) async {
    return await _unifiedService.performTransaction(action);
  }

  /// Cache multiple messages
  Future<void> cacheMessages(List<MessageModel> messages, String userId) async {
    for (final message in messages) {
      await cacheMessage(message, userId);
    }
  }

  /// Replace temporary message with actual message
  Future<void> replaceTempMessage(
      MessageModel tempMessage, MessageModel actualMessage) async {
    // Delete temp message
    await clearMessage(
        tempMessage.conversationId, tempMessage.id, actualMessage.senderId);
    // Cache actual message
    await cacheMessage(actualMessage, actualMessage.senderId);
  }

  /// Mark message as failed
  Future<void> markMessageAsFailed(
      String conversationId, String messageId) async {
    // For Hive implementation, we can update the message status
    // This is a simplified implementation
    print('[MessageCache] Marking message as failed: $messageId');
  }
}
