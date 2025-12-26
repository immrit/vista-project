import 'package:isar/isar.dart';
import 'isar_database_manager.dart';
import '../features/chat/data/entities/conversation_entity.dart';
import '../model/conversation_model.dart';
import '../security/logging_utility.dart';

class UnifiedConversationCacheService {
  static final UnifiedConversationCacheService _instance =
      UnifiedConversationCacheService._internal();

  factory UnifiedConversationCacheService() => _instance;

  UnifiedConversationCacheService._internal();

  Isar? _isar;

  Future<void> initialize() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      logInfo('✅ UnifiedConversationCacheService initialized');
    } catch (e) {
      logError('❌ Failed to initialize UnifiedConversationCacheService',
          error: e);
    }
  }

  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final entities =
            conversations.map((c) => ConversationEntity.fromModel(c)).toList();
        await _isar!.conversationEntitys.putAll(entities);
      });
    } catch (e) {
      logError('Error caching conversations', error: e);
    }
  }

  Future<List<ConversationModel>> getConversations(
      [String? userId, int limit = 50, int offset = 0]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return [];

    try {
      final entities = await _isar!.conversationEntitys
          .where()
          .sortByLastMessageTimeDesc() // Assuming validation of schema sorting
          .offset(offset)
          .limit(limit)
          .findAll();
      return entities.map((e) => e.toModel()).toList();
    } catch (e) {
      logError('Error fetching conversations', error: e);
      return [];
    }
  }

  Future<void> upsertConversation(ConversationModel conversation,
      [String? userId]) async {
    if (_isar == null) await initialize();
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

  Future<void> deleteConversation(String conversationId,
      [String? userId]) async {
    if (_isar == null) await initialize();
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

  Future<ConversationModel?> getConversation(String conversationId,
      [String? userId]) async {
    if (_isar == null) await initialize();
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

  Future<List<ConversationModel>> getCachedConversations([String? userId]) =>
      getConversations(userId);

  Future<void> cacheConversation(ConversationModel conversation,
          [String? userId]) =>
      upsertConversation(conversation, userId);

  Future<void> updateConversation(ConversationModel conversation,
          [String? userId]) =>
      upsertConversation(conversation, userId);

  Stream<List<ConversationModel>> watchCachedConversations(
      [String? userId]) async* {
    if (_isar == null) await initialize();
    if (_isar == null) yield [];

    try {
      yield* _isar!.conversationEntitys
          .where()
          .sortByLastMessageTimeDesc()
          .watch(fireImmediately: true)
          .map((entities) => entities.map((e) => e.toModel()).toList());
    } catch (e) {
      logError('Error observing conversations', error: e);
      yield [];
    }
  }

  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) async* {
    if (_isar == null) await initialize();
    if (_isar == null) yield null;

    try {
      yield* _isar!.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .watch(fireImmediately: true)
          .map((entities) =>
              entities.isNotEmpty ? entities.first.toModel() : null);
    } catch (e) {
      logError('Error observing conversation $conversationId', error: e);
      yield null;
    }
  }

  Future<void> clearAll() async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.conversationEntitys.clear();
      });
    } catch (e) {
      logError('Error clearing conversations', error: e);
    }
  }

  Future<void> removeConversation(String conversationId, [String? userId]) =>
      deleteConversation(conversationId, userId);

  Future<void> clearCache([String? userId]) => clearAll();

  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final conversation = await _isar!.conversationEntitys
            .filter()
            .idEqualTo(conversationId)
            .findFirst();
        if (conversation != null) {
          conversation.isPinned = isPinned;
          await _isar!.conversationEntitys.put(conversation);
        }
      });
    } catch (e) {
      logError('Error setting pin status', error: e);
    }
  }

  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final conversation = await _isar!.conversationEntitys
            .filter()
            .idEqualTo(conversationId)
            .findFirst();
        if (conversation != null) {
          conversation.isMuted = isMuted;
          await _isar!.conversationEntitys.put(conversation);
        }
      });
    } catch (e) {
      logError('Error setting mute status', error: e);
    }
  }

  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final conversation = await _isar!.conversationEntitys
            .filter()
            .idEqualTo(conversationId)
            .findFirst();
        if (conversation != null) {
          conversation.isArchived = isArchived;
          await _isar!.conversationEntitys.put(conversation);
        }
      });
    } catch (e) {
      logError('Error setting archive status', error: e);
    }
  }
}
