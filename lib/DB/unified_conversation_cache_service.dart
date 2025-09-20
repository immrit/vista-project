import '../model/conversation_model.dart';
import 'sembast_conversation_cache_service.dart';

/// Unified conversation cache service that works on all platforms
class UnifiedConversationCacheService {
  static final UnifiedConversationCacheService _instance =
      UnifiedConversationCacheService._internal();
  factory UnifiedConversationCacheService() => _instance;
  UnifiedConversationCacheService._internal();

  dynamic _service;

  Future<void> initialize() async {
    if (_service != null) return; // Already initialized

    try {
      // Always use Sembast for all platforms - it's fast and works on web and mobile
      await SembastConversationCacheService.initialize();
      _service = SembastConversationCacheService();
      print('Conversation cache service initialized successfully');
    } catch (e) {
      print('Error initializing conversation cache service: $e');
      rethrow;
    }
  }

  /// Cache a conversation
  Future<void> cacheConversation(
      ConversationModel conversation, String userId) async {
    if (_service == null) {
      await initialize();
    }
    await _service.cacheConversation(conversation, userId);
  }

  /// Get cached conversations for a user
  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    if (_service == null) {
      await initialize();
    }
    return await _service.getCachedConversations(userId);
  }

  /// Get a specific conversation
  Future<ConversationModel?> getConversation(
      String conversationId, String userId) async {
    if (_service == null) {
      await initialize();
    }
    return await _service.getConversation(conversationId, userId);
  }

  /// Update a conversation
  Future<void> updateConversation(
      ConversationModel conversation, String userId) async {
    if (_service == null) {
      await initialize();
    }
    await _service.updateConversation(conversation, userId);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId, String userId) async {
    if (_service == null) {
      await initialize();
    }
    await _service.deleteConversation(conversationId, userId);
  }

  /// Clear all conversations for a user
  Future<void> clearCache(String userId) async {
    if (_service == null) {
      await initialize();
    }
    await _service.clearCache(userId);
  }

  /// Set pin status
  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    if (_service == null) {
      await initialize();
    }
    await _service.setPinStatus(conversationId, userId, isPinned);
  }

  /// Set mute status
  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    if (_service == null) {
      await initialize();
    }
    await _service.setMuteStatus(conversationId, userId, isMuted);
  }

  /// Set archive status
  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    if (_service == null) {
      await initialize();
    }
    await _service.setArchiveStatus(conversationId, userId, isArchived);
  }

  /// Watch cached conversations
  Stream<List<ConversationModel>> watchCachedConversations(String userId) {
    if (_service == null) {
      // Initialize the service if not already done
      initialize().then((_) {
        // Service is now initialized
      }).catchError((error) {
        print('Error initializing conversation cache service: $error');
      });
      // Return empty stream while initializing
      return Stream.value([]);
    }
    return _service.watchCachedConversations(userId);
  }

  /// Watch a specific conversation
  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) {
    if (_service == null) {
      // Initialize the service if not already done
      initialize().then((_) {
        // Service is now initialized
      }).catchError((error) {
        print('Error initializing conversation cache service: $error');
      });
      // Return empty stream while initializing
      return Stream.value(null);
    }
    return _service.watchConversation(conversationId, userId);
  }

  /// Get conversation synchronously
  ConversationModel? getConversationSync(String conversationId) {
    if (_service == null) {
      print('Warning: ConversationCacheService not initialized');
      return null;
    }
    return _service.getConversationSync(conversationId);
  }

  /// Update last read
  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    if (_service == null) {
      await initialize();
    }
    await _service.updateLastRead(conversationId, readTimeIso);
  }

  /// Remove conversation
  Future<void> removeConversation(String conversationId, String userId) async {
    if (_service == null) {
      await initialize();
    }
    await _service.removeConversation(conversationId, userId);
  }
}
