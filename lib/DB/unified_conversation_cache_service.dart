import '../model/conversation_model.dart';
import 'advanced_cache_system.dart';

/// Unified conversation cache service that works on all platforms
class UnifiedConversationCacheService {
  static final UnifiedConversationCacheService _instance =
      UnifiedConversationCacheService._internal();
  factory UnifiedConversationCacheService() => _instance;
  UnifiedConversationCacheService._internal();

  final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();

  Future<void> initialize() async {
    await _advancedCache.initialize();
    print('UnifiedConversationCacheService initialized with Advanced Cache');
  }

  /// Cache a conversation
  Future<void> cacheConversation(
      ConversationModel conversation, String userId) async {
    // Advanced cache handles all the logic
    // No additional action needed as real-time updates handle this
  }

  /// Get cached conversations for a user
  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    return _advancedCache.getCachedConversations();
  }

  /// Get a specific conversation
  Future<ConversationModel?> getConversation(
      String conversationId, String userId) async {
    final conversations = _advancedCache.getCachedConversations();
    return conversations.where((c) => c.id == conversationId).firstOrNull;
  }

  /// Update a conversation
  Future<void> updateConversation(
      ConversationModel conversation, String userId) async {
    // Advanced cache handles updates through real-time sync
  }

  /// Clear conversations for a user
  Future<void> clearConversations(String userId) async {
    // Advanced cache doesn't support user-specific clearing in this simple implementation
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId, String userId) async {
    await _advancedCache.removeConversation(conversationId);
  }

  /// Clear all conversations for a user
  Future<void> clearCache(String userId) async {
    // Advanced cache handles clearing
  }

  /// Set pin status
  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    // Advanced cache handles pin status through real-time sync
  }

  /// Set mute status
  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    // Simple implementation
  }

  /// Set archive status
  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    // Simple implementation
  }

  /// Watch cached conversations
  Stream<List<ConversationModel>> watchCachedConversations(String userId) {
    return _advancedCache.watchConversations();
  }

  /// Watch a specific conversation
  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) {
    return _advancedCache.watchConversations().map((conversations) {
      return conversations.where((c) => c.id == conversationId).firstOrNull;
    });
  }

  /// Get conversation synchronously
  ConversationModel? getConversationSync(String conversationId) {
    // Simple implementation - not supported
    return null;
  }

  /// Update last read
  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    // Simple implementation
  }

  /// Remove conversation
  Future<void> removeConversation(String conversationId, String userId) async {
    await _advancedCache.removeConversation(conversationId);
  }

  /// Get unified service instance for initialization
  UnifiedConversationCacheService get unifiedService => this;
}
