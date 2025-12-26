import 'package:isar/isar.dart';
import 'isar_database_manager.dart';
import '../features/chat/data/entities/message_entity.dart';
import '../model/message_model.dart';
import '../security/logging_utility.dart';

class UnifiedMessageCacheService {
  static final UnifiedMessageCacheService _instance =
      UnifiedMessageCacheService._internal();

  factory UnifiedMessageCacheService() => _instance;

  UnifiedMessageCacheService._internal();

  Isar? _isar;

  Future<void> initialize() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      logInfo('✅ UnifiedMessageCacheService (Isar) initialized');
    } catch (e) {
      logError('❌ Failed to initialize UnifiedMessageCacheService', error: e);
    }
  }

  Future<List<MessageModel>> getConversationMessages(
      String conversationId, String userId,
      {int? limit, int? offset}) async {
    if (_isar == null) await initialize();
    if (_isar == null) return [];

    try {
      // Build query
      var query = _isar!.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAtDesc();

      List<MessageEntity> entities;

      if (offset != null && limit != null) {
        entities = await query.offset(offset).limit(limit).findAll();
      } else if (offset != null) {
        entities = await query.offset(offset).findAll();
      } else if (limit != null) {
        entities = await query.limit(limit).findAll();
      } else {
        entities = await query.findAll();
      }

      return entities.map((e) => e.toModel()).toList();
    } catch (e) {
      logError('Error fetching conversation messages from Isar', error: e);
      return [];
    }
  }

  Future<void> cacheMessages(List<MessageModel> messages, String userId) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final entities =
            messages.map((m) => MessageEntity.fromModel(m)).toList();
        await _isar!.messageEntitys.putAll(entities);
      });
    } catch (e) {
      logError('Error caching messages to Isar', error: e);
    }
  }

  // ✅ Cache Single Message (Positional optional userId)
  Future<void> cacheMessage(MessageModel message, [String? userId]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.messageEntitys.put(MessageEntity.fromModel(message));
      });
    } catch (e) {
      logError('Error caching single message', error: e);
    }
  }

  // ✅ Upsert Message alias
  Future<void> upsertMessage(MessageModel message, [String? userId]) async {
    await cacheMessage(message, userId);
  }

  // ✅ Clear Single Message (Delete) (3 args supported)
  Future<void> clearMessage(String conversationId, String messageId,
      [String? userId]) async {
    await deleteMessage(messageId, conversationId);
  }

  // ✅ Delete Message (Heuristic for 1 or 2 args)
  Future<void> deleteMessage(String arg1, [String? arg2]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    String messageId;
    // String? conversationId;

    if (arg2 != null) {
      // (conversationId, messageId) -> Wait, usually it is (conversationId, messageId) in caller?
      // But legacy deleteMessage(id) implies id is unique.
      // If caller passes 2 args, I assume the second is messageId if existing code was like that?
      // centralized_realtime_manager passes (conversationId: ..., messageId: ...)
      // If I convert to deleteMessage(cid, mid), then arg2 is mid.
      // If caller passes deleteMessage(mid), arg1 is mid.

      // Let's assume if 2 args, it is (conversationId, messageId).
      messageId = arg2;
    } else {
      // (messageId)
      messageId = arg1;
    }

    try {
      await _isar!.writeTxn(() async {
        await _isar!.messageEntitys.filter().idEqualTo(messageId).deleteAll();
      });
    } catch (e) {
      logError('Error deleting message', error: e);
    }
  }

  // ✅ Clear Conversation Messages (Accept optional userId)
  Future<void> clearConversationMessages(String conversationId,
      [String? userId]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.messageEntitys
            .filter()
            .conversationIdEqualTo(conversationId)
            .deleteAll();
      });
    } catch (e) {
      logError('Error clearing conversation messages', error: e);
    }
  }

  // ✅ Replace Temp Message (Dynamic first arg)
  Future<void> replaceTempMessage(
      dynamic tempIdOrMsg, MessageModel newMessage) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    String? tempId;
    if (tempIdOrMsg is String) {
      tempId = tempIdOrMsg;
    } else if (tempIdOrMsg is MessageModel) {
      tempId = tempIdOrMsg.id;
    }

    try {
      await _isar!.writeTxn(() async {
        if (tempId != null) {
          await _isar!.messageEntitys.filter().idEqualTo(tempId).deleteAll();
        }
        await _isar!.messageEntitys.put(MessageEntity.fromModel(newMessage));
      });
    } catch (e) {
      logError('Error replacing temp message', error: e);
    }
  }

  // ✅ Mark Message As Failed (2 args supported)
  Future<void> markMessageAsFailed(String messageId,
      [String? conversationId]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        final msg = await _isar!.messageEntitys
            .filter()
            .idEqualTo(messageId)
            .findFirst();
        if (msg != null) {
          msg.isFailed = true;
          await _isar!.messageEntitys.put(msg);
        }
      });
    } catch (e) {
      logError('Error marking message as failed', error: e);
    }
  }

  // ✅ Count Unread Messages (2 args, 2nd optional)
  Future<int> countUnreadMessages(String conversationId,
      [String? userId]) async {
    if (_isar == null) await initialize();
    if (_isar == null) return 0;

    try {
      if (userId != null && userId.isNotEmpty) {
        // Filter: ConversationID AND IsRead=False AND NOT(SenderID=UserId)
        return await _isar!.messageEntitys
            .filter()
            .conversationIdEqualTo(conversationId)
            .isReadEqualTo(false) // Filter unread first
            .not()
            .senderIdEqualTo(userId) // Not sent by me
            .count();
      } else {
        return await _isar!.messageEntitys
            .filter()
            .conversationIdEqualTo(conversationId)
            .isReadEqualTo(false)
            .count();
      }
    } catch (e) {
      logError('Error counting unread messages', error: e);
      return 0;
    }
  }

  // ✅ Delete Messages Older Than (Accept Duration or DateTime)
  Future<void> deleteMessagesOlderThan(dynamic durationOrDate) async {
    if (_isar == null) await initialize();
    if (_isar == null) return;

    DateTime cutoff;
    if (durationOrDate is DateTime) {
      cutoff = durationOrDate;
    } else if (durationOrDate is Duration) {
      cutoff = DateTime.now().subtract(durationOrDate);
    } else {
      logError('Invalid type for deleteMessagesOlderThan: $durationOrDate');
      return;
    }

    try {
      await _isar!.writeTxn(() async {
        await _isar!.messageEntitys
            .filter()
            .createdAtLessThan(cutoff)
            .deleteAll();
      });
      logInfo('Deleted messages older than $cutoff');
    } catch (e) {
      logError('Error deleting old messages', error: e);
    }
  }

  // ✅ Get Cached Messages (Alias)
  Future<List<MessageModel>> getCachedMessages(String conversationId,
      [String? userId]) async {
    return getConversationMessages(conversationId, userId ?? '');
  }

  // ✅ Clear All Cache
  Future<void> clearAllCache() async {
    if (_isar == null) await initialize();
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        await _isar!.messageEntitys.clear();
      });
    } catch (e) {
      logError('Error clearing all cache', error: e);
    }
  }

  // ✅ Watch Messages (Reactive Stream)
  Stream<List<MessageModel>> watchMessages(
      String conversationId, String userId) async* {
    if (_isar == null) await initialize();
    if (_isar == null) yield [];

    try {
      yield* _isar!.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAtDesc()
          .watch(fireImmediately: true)
          .map((entities) => entities.map((e) => e.toModel()).toList());
    } catch (e) {
      logError('Error watching messages in Isar', error: e);
      yield [];
    }
  }
}
