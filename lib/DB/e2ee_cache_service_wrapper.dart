import 'unified_e2ee_cache_service.dart';

/// Wrapper for E2EEDecryptedCacheService that uses unified services
class E2EEDecryptedCacheService {
  static final E2EEDecryptedCacheService _instance =
      E2EEDecryptedCacheService._internal();
  factory E2EEDecryptedCacheService() => _instance;
  E2EEDecryptedCacheService._internal();

  final UnifiedE2EECacheService _unifiedService = UnifiedE2EECacheService();

  /// Cache a decrypted message
  Future<void> cacheDecryptedMessage({
    required String messageId,
    required String conversationId,
    required String userId,
    required String decryptedContent,
    String? decryptedReplyContent,
    required DateTime createdAt,
  }) async {
    return await _unifiedService.cacheDecryptedMessage(
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
    return await _unifiedService.getDecryptedContent(
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
    return await _unifiedService.getDecryptedReplyContent(
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
    return await _unifiedService.clearConversationCache(
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
    return await _unifiedService.clearMessageCache(
      messageId: messageId,
      conversationId: conversationId,
      userId: userId,
    );
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    return await _unifiedService.clearAllCache();
  }

  /// Delete old cache entries
  Future<void> deleteOldCache({int daysOld = 30}) async {
    return await _unifiedService.deleteOldCache(daysOld: daysOld);
  }
}

