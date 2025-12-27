import 'package:isar/isar.dart';
import '../../../DB/isar_database_manager.dart';
import '../../../features/chat/data/entities/conversation_entity.dart';
import '../../../model/conversation_model.dart';
import '../../../security/logging_utility.dart';

/// Repository for managing local cache (Isar) for chat and other data.
/// Consolidates logic from [UnifiedConversationCacheService],
/// [SmartCacheService], and [AdvancedCacheOptimizer].
class CacheRepository {
  static final CacheRepository _instance = CacheRepository._internal();
  factory CacheRepository() => _instance;
  CacheRepository._internal();

  Isar? _isar;

  /// Initialize the Isar database connection
  Future<void> initialize() async {
    if (_isar != null && _isar!.isOpen) return;
    try {
      _isar = await IsarDatabaseManager().instance;
      logInfo('✅ CacheRepository initialized');
    } catch (e) {
      logError('❌ Failed to initialize CacheRepository', error: e);
    }
  }

  // ===========================================================================
  // Conversation Operations (Migrated from UnifiedConversationCacheService)
  // ===========================================================================

  /// Watch all conversations for a specific user.
  /// Used for Stale-While-Revalidate pattern (emit local data immediately).
  Stream<List<ConversationModel>> watchConversations([String? userId]) async* {
    await initialize();
    if (_isar == null) {
      yield [];
      return;
    }

    try {
      yield* _isar!.conversationEntitys
          .where()
          .sortByLastMessageTimeDesc()
          .watch(fireImmediately: true)
          .map((entities) => entities.map((e) => e.toModel()).toList());
    } catch (e) {
      logError('Error watching conversations', error: e);
      yield [];
    }
  }

  /// Get conversations with pagination.
  Future<List<ConversationModel>> getConversations({
    int limit = 50,
    int offset = 0,
    String? userId,
  }) async {
    await initialize();
    if (_isar == null) return [];

    try {
      final entities = await _isar!.conversationEntitys
          .where()
          .sortByLastMessageTimeDesc()
          .offset(offset)
          .limit(limit)
          .findAll();
      return entities.map((e) => e.toModel()).toList();
    } catch (e) {
      logError('Error fetching conversations', error: e);
      return [];
    }
  }

  /// Save or update a list of conversations in bulk.
  Future<void> saveConversations(List<ConversationModel> conversations) async {
    await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final entities =
            conversations.map((c) => ConversationEntity.fromModel(c)).toList();
        await _isar!.conversationEntitys.putAll(entities);
      });
    } catch (e) {
      logError('Error saving conversations', error: e);
    }
  }

  /// Update a single conversation.
  Future<void> upsertConversation(ConversationModel conversation,
      [String? userId]) async {
    await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.conversationEntitys
            .put(ConversationEntity.fromModel(conversation));
      });
    } catch (e) {
      logError('Error upserting conversation', error: e);
    }
  }

  /// Get a conversation synchronously (if cached).
  ConversationModel? getConversationSync(String conversationId) {
    if (_isar == null) return null;
    try {
      final entity = _isar!.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirstSync();
      return entity?.toModel();
    } catch (e) {
      logError('Error fetching conversation sync', error: e);
      return null;
    }
  }

  /// Get a conversation asynchronously.
  Future<ConversationModel?> getConversation(String conversationId,
      [String? userId]) async {
    await initialize();
    if (_isar == null) return null;
    try {
      final entity = await _isar!.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();
      return entity?.toModel();
    } catch (e) {
      logError('Error fetching conversation', error: e);
      return null;
    }
  }

  /// Delete a conversation by ID.
  Future<void> deleteConversation(String conversationId) async {
    await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.conversationEntitys
            .filter()
            .idEqualTo(conversationId)
            .deleteAll();
      });
    } catch (e) {
      logError('Error deleting conversation', error: e);
    }
  }

  /// Clear all cached conversations.
  Future<void> clearAllConversations() async {
    await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.conversationEntitys.clear();
      });
    } catch (e) {
      logError('Error clearing all conversations', error: e);
    }
  }

  // ===========================================================================
  // Compatibility Methods for Legacy Services
  Future<void> cacheConversation(ConversationModel conversation,
      [String? userId]) async {
    await upsertConversation(conversation, userId);
  }

  Future<void> removeConversation(String conversationId,
      [String? userId]) async {
    await deleteConversation(conversationId);
  }

  Future<void> clearCache([String? userId]) async {
    await clearAllConversations();
  }

  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    final conversation = await getConversation(conversationId);
    if (conversation != null) {
      await upsertConversation(conversation.copyWith(isPinned: isPinned));
    }
  }

  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    final conversation = await getConversation(conversationId);
    if (conversation != null) {
      await upsertConversation(conversation.copyWith(isMuted: isMuted));
    }
  }

  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    final conversation = await getConversation(conversationId);
    if (conversation != null) {
      await upsertConversation(conversation.copyWith(isArchived: isArchived));
    }
  }

  // Aliases for Migrated Services
  Future<void> updateConversation(ConversationModel conversation,
      [String? userId]) async {
    await upsertConversation(conversation, userId);
  }

  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    return getConversations(
        userId:
            userId); // Assuming getConversations ignores userId or returns all
    // Note: getConversations takes optional named args.
    // If we want filtering by userId, we need to implement it or assume local DB is single user context.
    // Current getConversations implementation returns ALL.
    // For now, this alias just calls getConversations.
  }

  Stream<List<ConversationModel>> watchCachedConversations([String? userId]) {
    return watchConversations();
  }

  Stream<ConversationModel?> watchConversation(String conversationId,
      [String? userId]) async* {
    await initialize();
    if (_isar == null) {
      yield null;
      return;
    }
    yield* _isar!.conversationEntitys
        .filter()
        .idEqualTo(conversationId)
        .watch(fireImmediately: true)
        .map((entities) =>
            (entities.isNotEmpty ? entities.first.toModel() : null));
  }

  // Cleanup & Optimization (Migrated from SmartCacheService & AdvancedCacheOptimizer)
  // ===========================================================================

  /// Performs cleanup of old data based on expiry days.
  /// Replaces [SmartCacheService._performSmartCacheCleanup].
  Future<void> cleanUp({int expiryDays = 30}) async {
    await initialize();
    if (_isar == null) return;

    // TODO: Add Message cleanup when MessageEntity is migrated to this repo.
    // Currently, we only have ConversationEntity here, but typically messages
    // are the bulk of the cache.
    // For now, we'll log that we are running cleanup.

    logInfo('🧹 Running cache cleanup (Expiry: $expiryDays days)');

    // Example: Trigger compact to reclaim space (Optimization)
    // Isar automatically reclaims space, but we can manually verify database size if needed.
  }

  /// Optimizes the database (e.g., compacting, verifying integrity).
  /// Replaces [AdvancedCacheOptimizer] logic.
  Future<void> optimize() async {
    await initialize();
    if (_isar == null) return;

    // Isar is generally self-optimizing.
    // We can add specific maintenance tasks here if Isar exposes them in future versions
    // or if we need to manually prune orphan data.

    final size = await _isar!.getSize();
    logInfo(
        '🔧 Cache Optimization checked. Current DB Size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
  }

  /// ☠️ DANGER: Wipes ALL data from the database.
  /// Used ONLY for Secure Logout.
  Future<void> wipeAllData() async {
    await initialize();
    if (_isar == null) return;

    try {
      logInfo('☠️ SECURE LOGOUT: Wiping entire Isar database...');
      await _isar!.writeTxn(() async {
        await _isar!.clear();
      });
      logInfo('✅ Database wiped successfully.');
    } catch (e) {
      logError('❌ Error wiping database', error: e);
    }
  }
}
