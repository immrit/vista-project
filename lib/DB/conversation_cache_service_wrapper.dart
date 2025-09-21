import '../model/conversation_model.dart';
import 'unified_conversation_cache_service.dart';

/// Wrapper for ConversationCacheService that uses unified services
class ConversationCacheService {
  static final ConversationCacheService _instance =
      ConversationCacheService._internal();
  factory ConversationCacheService() => _instance;
  ConversationCacheService._internal();

  final UnifiedConversationCacheService _unifiedService =
      UnifiedConversationCacheService();

  /// Initialize the cache service
  Future<void> initialize() async {
    await _unifiedService.initialize();
  }

  /// Cache a conversation
  Future<void> cacheConversation(
      ConversationModel conversation, String userId) async {
    return await _unifiedService.cacheConversation(conversation, userId);
  }

  /// Get cached conversations for a user
  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    return await _unifiedService.getCachedConversations(userId);
  }

  /// Get a specific conversation
  Future<ConversationModel?> getConversation(
      String conversationId, String userId) async {
    return await _unifiedService.getConversation(conversationId, userId);
  }

  /// Update a conversation
  Future<void> updateConversation(
      ConversationModel conversation, String userId) async {
    return await _unifiedService.updateConversation(conversation, userId);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId, String userId) async {
    return await _unifiedService.deleteConversation(conversationId, userId);
  }

  /// Clear all conversations for a user
  Future<void> clearCache(String userId) async {
    return await _unifiedService.clearCache(userId);
  }

  /// Set pin status
  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    return await _unifiedService.setPinStatus(conversationId, userId, isPinned);
  }

  /// Set mute status
  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    return await _unifiedService.setMuteStatus(conversationId, userId, isMuted);
  }

  /// Set archive status
  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    return await _unifiedService.setArchiveStatus(
        conversationId, userId, isArchived);
  }

  /// Watch cached conversations
  Stream<List<ConversationModel>> watchCachedConversations(String userId) {
    return _unifiedService.watchCachedConversations(userId);
  }

  /// Watch a specific conversation
  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) {
    return _unifiedService.watchConversation(conversationId, userId);
  }

  /// Get conversation synchronously
  ConversationModel? getConversationSync(String conversationId) {
    return _unifiedService.getConversationSync(conversationId);
  }

  /// Update last read
  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    return await _unifiedService.updateLastRead(conversationId, readTimeIso);
  }

  /// Remove conversation
  Future<void> removeConversation(String conversationId, String userId) async {
    return await _unifiedService.removeConversation(conversationId, userId);
  }

  /// Get unified service instance for initialization
  UnifiedConversationCacheService get unifiedService => _unifiedService;
}
