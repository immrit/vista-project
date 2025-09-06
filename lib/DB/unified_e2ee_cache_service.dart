import 'database_platform.dart';
import 'sembast_e2ee_cache_service.dart';

/// Unified E2EE cache service that works on all platforms
class UnifiedE2EECacheService {
  static final UnifiedE2EECacheService _instance =
      UnifiedE2EECacheService._internal();
  factory UnifiedE2EECacheService() => _instance;
  UnifiedE2EECacheService._internal();

  dynamic _service;

  Future<void> initialize() async {
    // Always use Sembast for all platforms - it's fast and works on web and mobile
    await SembastE2EECacheService.initialize();
    _service = SembastE2EECacheService();
  }

  /// Cache a decrypted message
  Future<void> cacheDecryptedMessage({
    required String messageId,
    required String conversationId,
    required String userId,
    required String decryptedContent,
    String? decryptedReplyContent,
    required DateTime createdAt,
  }) async {
    if (_service == null) {
      await initialize();
    }
    await _service.cacheDecryptedMessage(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
      decryptedContent: decryptedContent,
      decryptedReplyContent: decryptedReplyContent,
      createdAt: createdAt,
    );
  }

  /// Get decrypted content for a message
  Future<String?> getDecryptedContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    if (_service == null) {
      await initialize();
    }
    return await _service.getDecryptedContent(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Get decrypted reply content for a message
  Future<String?> getDecryptedReplyContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    if (_service == null) {
      await initialize();
    }
    return await _service.getDecryptedReplyContent(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Clear cache for a conversation
  Future<void> clearConversationCache({
    required String conversationId,
    required String userId,
  }) async {
    if (_service == null) {
      await initialize();
    }
    await _service.clearConversationCache(
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Clear cache for a specific message
  Future<void> clearMessageCache({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    if (_service == null) {
      await initialize();
    }
    await _service.clearMessageCache(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    if (_service == null) {
      await initialize();
    }
    await _service.clearAllCache();
  }

  /// Delete old cache entries
  Future<void> deleteOldCache({int daysOld = 30}) async {
    if (_service == null) {
      await initialize();
    }
    await _service.deleteOldCache(daysOld: daysOld);
  }
}
