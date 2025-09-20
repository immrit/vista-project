import '../model/message_model.dart';
import 'sembast_message_cache_service.dart';

/// Unified message cache service that works on all platforms
class UnifiedMessageCacheService {
  static final UnifiedMessageCacheService _instance =
      UnifiedMessageCacheService._internal();
  factory UnifiedMessageCacheService() => _instance;
  UnifiedMessageCacheService._internal();

  dynamic _service;

  Future<void> initialize() async {
    // Always use Sembast for all platforms - it's fast and works on web and mobile
    await SembastMessageCacheService.initialize();
    _service = SembastMessageCacheService();
  }

  /// Cache a message
  Future<void> cacheMessage(MessageModel message, String userId) async {
    await _service.cacheMessage(message, userId);
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>> getCachedMessages(
      String conversationId, String userId) async {
    return await _service.getCachedMessages(conversationId, userId);
  }

  /// Get a specific message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId, String userId) async {
    return await _service.getMessage(conversationId, messageId, userId);
  }

  /// Update a message
  Future<void> updateMessage(MessageModel message, String userId) async {
    await _service.updateMessage(message, userId);
  }

  /// Clear messages for a conversation
  Future<void> clearConversationMessages(
      String conversationId, String userId) async {
    await _service.clearConversationMessages(conversationId, userId);
  }

  /// Clear a specific message
  Future<void> clearMessage(
      String conversationId, String messageId, String userId) async {
    await _service.clearMessage(conversationId, messageId, userId);
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    await _service.clearAllCache();
  }

  /// Delete messages older than specified date
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    await _service.deleteMessagesOlderThan(date);
  }

  /// Count unread messages
  Future<int> countUnreadMessages(String conversationId) async {
    return await _service.countUnreadMessages(conversationId);
  }

  /// Perform transaction
  Future<void> performTransaction(Future<void> Function() action) async {
    await _service.performTransaction(action);
  }
}
