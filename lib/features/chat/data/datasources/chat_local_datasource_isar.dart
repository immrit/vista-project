import 'package:isar/isar.dart';
import '../../../../model/message_model.dart';
import '../../../../model/conversation_model.dart';
import '../../../../DB/isar_database_manager.dart';
import '../entities/message_entity.dart';
import '../entities/conversation_entity.dart';

class ChatLocalDataSourceIsar {
  final IsarDatabaseManager _dbManager; // Assuming Injection or instantiate

  // ── Throttle state for upload progress ──
  static final Map<String, int> _lastProgressWriteMs = {};
  static final Map<String, double> _lastProgressValue = {};
  static const int _progressThrottleMs = 120; // حداقل فاصله بین write‌ها
  static const double _progressMinDelta = 0.01; // حداقل تغییر ۱٪

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
    await isar.writeTxn(() async {
      for (final message in messages) {
        final existing = await isar.messageEntitys
            .filter()
            .idEqualTo(message.id)
            .findFirst();
        final merged =
            _mergeWithExistingLocalFields(message, existing?.toModel());
        await isar.messageEntitys.put(MessageEntity.fromModel(merged));
      }
    });
  }

  Future<void> saveMessage(MessageModel message) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final existing =
          await isar.messageEntitys.filter().idEqualTo(message.id).findFirst();
      final merged =
          _mergeWithExistingLocalFields(message, existing?.toModel());

      // 1. Save Message
      await isar.messageEntitys.put(MessageEntity.fromModel(merged));

      // 2. Update Conversation Metadata (Last Message & Unread Count)
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(message.conversationId)
          .findFirst();

      if (conversation != null) {
        conversation.lastMessage = merged.content; // Or proper snippet
        conversation.lastMessageTime = merged.createdAt;
        conversation.updatedAt = merged.createdAt; // Sort by this

        // If message is NOT from me, increment unread count
        if (!merged.isMe) {
          // If we are currently in this chat, don't increment (Handled by repo usually, but good to check)
          // However, repo handles logic. Ideally here we just increment.
          // But valid 'unread' logic usually depends on if the user has read it.
          // If isSeen is false and it's not me, increment.
          if (!merged.isSeen) {
            conversation.unreadCount = conversation.unreadCount + 1;
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

  MessageModel _mergeWithExistingLocalFields(
    MessageModel incoming,
    MessageModel? existing,
  ) {
    if (existing == null) return incoming;

    return incoming.copyWith(
      attachmentFileName:
          incoming.attachmentFileName ?? existing.attachmentFileName,
      attachmentMimeType:
          incoming.attachmentMimeType ?? existing.attachmentMimeType,
      attachmentSizeBytes:
          incoming.attachmentSizeBytes ?? existing.attachmentSizeBytes,
      audioTitle: incoming.audioTitle ?? existing.audioTitle,
      audioArtist: incoming.audioArtist ?? existing.audioArtist,
      audioAlbum: incoming.audioAlbum ?? existing.audioAlbum,
      duration: incoming.duration ?? existing.duration,
      localImagePath: incoming.localImagePath ?? existing.localImagePath,
      localFilePath: incoming.localFilePath ?? existing.localFilePath,
    );
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

  Future<void> updateUploadProgress(String messageId, double progress) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final isComplete = clamped >= 1.0;

    // ── Throttle: اجتناب از write بیش از حد ──
    if (!isComplete) {
      final lastMs = _lastProgressWriteMs[messageId] ?? 0;
      final lastVal = _lastProgressValue[messageId] ?? -1.0;
      final elapsed = now - lastMs;
      final delta = (clamped - lastVal).abs();

      // Never move backward while upload is in progress.
      if (lastVal >= 0 && clamped < lastVal) {
        return;
      }

      if (elapsed < _progressThrottleMs && delta < _progressMinDelta) {
        return; // skip write
      }
    }

    _lastProgressWriteMs[messageId] = now;
    _lastProgressValue[messageId] = clamped;

    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final entity =
          await isar.messageEntitys.filter().idEqualTo(messageId).findFirst();
      if (entity == null) return;
      entity.uploadProgress = clamped;
      entity.isUploading = true;
      entity.isPending = true;
      entity.isFailed = false;
      entity.errorMessage = null;
      await isar.messageEntitys.put(entity);
    });

    // پاکسازی state throttle هنگام تکمیل
    if (isComplete) {
      _lastProgressWriteMs.remove(messageId);
      _lastProgressValue.remove(messageId);
    }
  }

  Future<void> markUploadFailed(
    String messageId, {
    String? errorMessage,
  }) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final entity =
          await isar.messageEntitys.filter().idEqualTo(messageId).findFirst();
      if (entity == null) return;
      entity.isUploading = false;
      entity.isPending = false;
      entity.isFailed = true;
      entity.errorMessage = errorMessage;
      await isar.messageEntitys.put(entity);
    });
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

  Future<List<ConversationModel>> getConversations() async {
    final isar = await _dbManager.instance;
    final entities =
        await isar.conversationEntitys.where().sortByUpdatedAtDesc().findAll();
    return entities.map((e) => e.toModel()).toList();
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

  Future<void> clearAllData() async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      await isar.messageEntitys.clear();
      await isar.conversationEntitys.clear();
    });
  }
}
