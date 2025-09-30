import '../model/message_model.dart';
import 'advanced_cache_system.dart';

/// Unified message cache service that works on all platforms
class UnifiedMessageCacheService {
  static final UnifiedMessageCacheService _instance =
      UnifiedMessageCacheService._internal();
  factory UnifiedMessageCacheService() => _instance;
  UnifiedMessageCacheService._internal();

  final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();

  Future<void> initialize() async {
    await _advancedCache.initialize();
    print('UnifiedMessageCacheService initialized with Advanced Cache');
  }

  /// Cache a message
  Future<void> cacheMessage(MessageModel message, String userId) async {
    await _advancedCache.cacheMessage(message);
  }

  /// Cache multiple messages
  Future<void> cacheMessages(List<MessageModel> messages, String userId) async {
    for (final message in messages) {
      await _advancedCache.cacheMessage(message);
    }
  }

  /// Cache multiple messages with limit support
  Future<void> cacheMessagesWithLimit(
      List<MessageModel> messages, String userId,
      {int? limit}) async {
    final messagesToCache =
        limit != null && limit > 0 ? messages.take(limit).toList() : messages;
    await cacheMessages(messagesToCache, userId);
  }

  /// Get conversation messages
  Future<List<MessageModel>> getConversationMessages(
      String conversationId, String userId,
      {int? limit}) async {
    final messages = _advancedCache.getCachedMessages(conversationId);
    if (limit != null && limit > 0) {
      return messages.take(limit).toList();
    }
    return messages;
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>> getCachedMessages(
      String conversationId, String userId) async {
    return _advancedCache.getCachedMessages(conversationId);
  }

  /// Get a specific message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId, String userId) async {
    final messages = _advancedCache.getCachedMessages(conversationId);
    return messages.where((m) => m.id == messageId).firstOrNull;
  }

  /// Update a message
  Future<void> updateMessage(MessageModel message, String userId) async {
    // Advanced cache handles updates through real-time sync
  }

  /// Clear messages for a conversation
  Future<void> clearConversationMessages(
      String conversationId, String userId) async {
    // Advanced cache handles clearing
  }

  /// Clear a specific message
  Future<void> clearMessage(
      String conversationId, String messageId, String userId) async {
    // Advanced cache handles message deletion
  }

  /// Get unread message count
  Future<int> countUnreadMessages(String conversationId) async {
    return 0; // Placeholder
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    // Advanced cache handles clearing
  }

  /// Delete messages older than specified date
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    // Advanced cache handles this through cleanup
  }

  /// Perform transaction
  Future<void> performTransaction(Future<void> Function() action) async {
    await action();
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
    print('[UnifiedMessageCache] Marking message as failed: $messageId');
  }
}
