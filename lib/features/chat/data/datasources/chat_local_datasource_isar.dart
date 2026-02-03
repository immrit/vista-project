import 'package:isar/isar.dart';
import '../../../../model/message_model.dart';
import '../../../../model/conversation_model.dart';
import '../../../../DB/isar_database_manager.dart';
import '../entities/message_entity.dart';
import '../entities/conversation_entity.dart';

class ChatLocalDataSourceIsar {
  final IsarDatabaseManager _dbManager; // Assuming Injection or instantiate

  ChatLocalDataSourceIsar({IsarDatabaseManager? dbManager})
      : _dbManager = dbManager ?? IsarDatabaseManager();

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  Stream<List<MessageModel>> watchMessages(
      String conversationId, String currentUserId) async* {
    final isar = await _dbManager.instance;
    yield* isar.messageEntitys
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc() // Isar auto-generates this
        .watch(fireImmediately: true)
        .map((entities) => entities.map((e) => e.toModel()).toList());
  }

  Future<void> saveMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    final isar = await _dbManager.instance;
    final entities = messages.map(MessageEntity.fromModel).toList();

    await isar.writeTxn(() async {
      await isar.messageEntitys.putAll(entities);
    });
  }

  Future<void> saveMessage(MessageModel message) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      // 1. Save Message
      await isar.messageEntitys.put(MessageEntity.fromModel(message));

      // 2. Update Conversation Metadata (Last Message & Unread Count)
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(message.conversationId)
          .findFirst();

      if (conversation != null) {
        conversation.lastMessage = message.content; // Or proper snippet
        conversation.lastMessageTime = message.createdAt;
        conversation.updatedAt = message.createdAt; // Sort by this

        // If message is NOT from me, increment unread count
        if (!message.isMe) {
          // If we are currently in this chat, don't increment (Handled by repo usually, but good to check)
          // However, repo handles logic. Ideally here we just increment.
          // But valid 'unread' logic usually depends on if the user has read it.
          // If isSeen is false and it's not me, increment.
          if (!message.isSeen) {
            conversation.unreadCount = (conversation.unreadCount ?? 0) + 1;
          }
        }

        // If it IS me, typically unread count doesn't change for ME, but for THEM.
        // But the conversation list shows MY unread count.

        await isar.conversationEntitys.put(conversation);
      } else {
        // If conversation doesn't exist locally, we might want to create a ghost one?
        // Or wait for 'getConversations'.
        // For now, let's assume it exists or will be fetched.
      }
    });
  }

  Future<void> resetUnreadCount(String conversationId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();

      if (conversation != null) {
        conversation.unreadCount = 0;
        await isar.conversationEntitys.put(conversation);
      }
    });
  }

  Future<void> markMessagesAsSeenLocally(String conversationId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      // 1. Update Messages
      final messages = await isar.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .isSeenEqualTo(false) // Find unseen
          .isMeEqualTo(false) // That are not mine (I see others' messages)
          .findAll();

      for (var msg in messages) {
        msg.isSeen = true;
        await isar.messageEntitys.put(msg);
      }

      // 2. Reset Unread Count (just to be safe)
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();

      if (conversation != null) {
        conversation.unreadCount = 0;
        await isar.conversationEntitys.put(conversation);
      }
    });
  }

  Future<MessageModel?> getMessage(
      String messageId, String currentUserId) async {
    final isar = await _dbManager.instance;
    final entity =
        await isar.messageEntitys.filter().idEqualTo(messageId).findFirst();
    return entity?.toModel();
  }

  Future<void> deleteMessage(String messageId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      await isar.messageEntitys.filter().idEqualTo(messageId).deleteAll();
    });
  }

  Future<void> reconcileMessages(
      String conversationId, List<MessageModel> serverMessages) async {
    if (serverMessages.isEmpty) return;
    final isar = await _dbManager.instance;

    // 1. Get date range
    final sortedServer = List<MessageModel>.from(serverMessages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final oldestServerDate = sortedServer.first.createdAt;

    // 2. Find local messages in range (that presumably SHOULD match server content)
    // CRITICAL: Exclude pending/failed messages to prevent deleting messages being sent.
    final localEntities = await isar.messageEntitys
        .filter()
        .conversationIdEqualTo(conversationId)
        .createdAtGreaterThan(oldestServerDate, include: true)
        .isPendingEqualTo(false) // Protect pending
        .isFailedEqualTo(false) // Protect failed
        .findAll();

    final localIds = localEntities.map((e) => e.id).toSet();
    final serverIds = serverMessages.map((m) => m.id).toSet();

    final idsToDelete = localIds.difference(serverIds).toList();

    if (idsToDelete.isNotEmpty) {
      await isar.writeTxn(() async {
        // Delete ghost messages
        for (var id in idsToDelete) {
          await isar.messageEntitys.filter().idEqualTo(id).deleteAll();
        }
      });
    }

    await saveMessages(serverMessages);
  }

  Future<void> clearMessages(String conversationId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      await isar.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .deleteAll();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  Stream<List<ConversationModel>> watchConversations(
      String currentUserId) async* {
    final isar = await _dbManager.instance;
    yield* isar.conversationEntitys
        .where()
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true)
        .map((entities) => entities.map((e) => e.toModel()).toList());
  }

  Future<void> saveConversations(List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return;
    final isar = await _dbManager.instance;
    final entities = conversations.map(ConversationEntity.fromModel).toList();
    await isar.writeTxn(() async {
      await isar.conversationEntitys.putAll(entities);
    });
  }

  Future<void> saveConversation(ConversationModel conversation) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      await isar.conversationEntitys
          .put(ConversationEntity.fromModel(conversation));
    });
  }

  Future<ConversationModel?> getConversation(
      String conversationId, String currentUserId) async {
    final isar = await _dbManager.instance;
    // Note: 'id' is indexed as String in our Entity
    final entity = await isar.conversationEntitys
        .filter()
        .idEqualTo(conversationId)
        .findFirst();
    return entity?.toModel();
  }

  Future<void> deleteConversation(String conversationId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .deleteAll();
    });
  }
}
