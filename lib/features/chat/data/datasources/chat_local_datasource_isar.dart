import 'package:isar/isar.dart';
import '../../../../model/message_model.dart';
import '../../../../model/conversation_model.dart';
import '../../../../DB/isar_database_manager.dart';
import '../../utils/conversation_name_utils.dart';
import '../entities/message_entity.dart' hide fastHash;
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
      final existingById = await _loadExistingMessagesById(
        isar,
        messages.map((m) => m.id),
      );
      final touchedConversationIds = <String>{};
      for (final message in messages) {
        final existingModel = existingById[message.id];
        final merged = _mergeWithExistingLocalFields(message, existingModel);
        if (existingModel != null &&
            _isMessageEffectivelySame(existingModel, merged)) {
          continue;
        }
        await isar.messageEntitys.put(MessageEntity.fromModel(merged));
        touchedConversationIds.add(merged.conversationId);
      }

      for (final conversationId in touchedConversationIds) {
        await _rebuildConversationMetadataInTxn(isar, conversationId);
      }
    });
  }

  Future<void> saveMessage(MessageModel message) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final existing =
          await isar.messageEntitys.filter().idEqualTo(message.id).findFirst();
      final existingModel = existing?.toModel();
      final merged = _mergeWithExistingLocalFields(message, existingModel);
      final existingMessage = existingModel;
      final hadIncomingUnseenBefore = existingMessage != null &&
          existingMessage.isMe == false &&
          existingMessage.isSeen == false &&
          existingMessage.isRead == false;
      final shouldIncrementUnread = merged.isMe == false &&
          merged.isSeen == false &&
          merged.isRead == false &&
          !hadIncomingUnseenBefore;
      final shouldRecountUnread = existingMessage != null &&
          existingMessage.isMe == false &&
          existingMessage.isSeen == false &&
          existingMessage.isRead == false &&
          (merged.isSeen == true || merged.isRead == true);

      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(message.conversationId)
          .findFirst();
      if (existingModel != null &&
          conversation != null &&
          _isMessageEffectivelySame(existingModel, merged)) {
        return;
      }

      // 1. Save Message
      await isar.messageEntitys.put(MessageEntity.fromModel(merged));

      // 2. Update Conversation Metadata (Last Message & Unread Count)
      if (conversation != null) {
        final isLatestMessage = conversation.lastMessageTime == null ||
            !merged.createdAt.isBefore(conversation.lastMessageTime!);

        if (isLatestMessage) {
          conversation.lastMessage = merged.content;
          conversation.lastMessageTime = merged.createdAt;

          if (merged.createdAt.isAfter(conversation.updatedAt)) {
            conversation.updatedAt = merged.createdAt;
          }

          // ذخیره جزییات آخرین پیام برای نمایش بهتر بج‌ها و وضعیت پیام
          conversation.lastMessageType = merged.attachmentType ?? 'text';
          conversation.isLastMessageFromMe = merged.isMe;
          conversation.lastMessageSenderId = merged.senderId;

          // تنظیم وضعیت تحویل آخرین پیام
          if (merged.isPending == true) {
            conversation.lastMessageDeliveryStatus = 'pending';
          } else if (merged.isFailed == true) {
            conversation.lastMessageDeliveryStatus = 'failed';
          } else if (merged.isMe &&
              (merged.isSeen == true || merged.isRead == true)) {
            conversation.lastMessageDeliveryStatus = 'read';
          } else if (merged.isDelivered == true) {
            conversation.lastMessageDeliveryStatus = 'delivered';
          } else if (merged.isSent == true) {
            conversation.lastMessageDeliveryStatus = 'sent';
          } else {
            conversation.lastMessageDeliveryStatus = 'sent';
          }
        }

        if (shouldIncrementUnread) {
          conversation.unreadCount += 1;
        }
        if (shouldRecountUnread) {
          conversation.unreadCount = await isar.messageEntitys
              .filter()
              .conversationIdEqualTo(message.conversationId)
              .isMeEqualTo(false)
              .isSeenEqualTo(false)
              .isReadEqualTo(false)
              .count();
        }
        if (conversation.unreadCount < 0) {
          conversation.unreadCount = 0;
        }
        conversation.hasUnreadMessages = conversation.unreadCount > 0;

        await isar.conversationEntitys.put(conversation);
      } else {
        final placeholder = ConversationEntity()
          ..isarId = fastHash(message.conversationId)
          ..id = message.conversationId
          ..createdAt = merged.createdAt
          ..updatedAt = merged.createdAt
          ..lastMessage = merged.content
          ..lastMessageTime = merged.createdAt
          ..lastMessageType = merged.attachmentType ?? 'text'
          ..isLastMessageFromMe = merged.isMe
          ..lastMessageSenderId = merged.senderId
          ..lastMessageDeliveryStatus = _messageDeliveryStatusToString(merged)
          ..otherUserName = unknownConversationUserLabel
          ..otherUserId = merged.isMe ? null : merged.senderId
          ..otherUserName = _initialOtherUserNameFromMessage(merged)
          ..unreadCount = shouldIncrementUnread ? 1 : 0
          ..hasUnreadMessages = shouldIncrementUnread
          ..type = 'private';
        await isar.conversationEntitys.put(placeholder);
      }
    });
  }

  String? _preferNonEmptyUrl(String? primary, String? fallback) {
    final primaryValue = primary?.trim() ?? '';
    if (primaryValue.isNotEmpty) return primaryValue;
    final fallbackValue = fallback?.trim() ?? '';
    return fallbackValue.isNotEmpty ? fallbackValue : null;
  }

  String _mergeIncomingContent(MessageModel incoming, MessageModel? existing) {
    if (!incoming.hasMediaPlaceholderContent) return incoming.content;
    if (existing != null && !existing.hasMediaPlaceholderContent) {
      return existing.content;
    }
    if (incoming.resolvedMediaUrl != null ||
        existing?.resolvedMediaUrl != null) {
      return '';
    }
    return incoming.content;
  }

  MessageModel _mergeWithExistingLocalFields(
    MessageModel incoming,
    MessageModel? existing,
  ) {
    if (existing == null) return incoming;

    return incoming.copyWith(
      content: _mergeIncomingContent(incoming, existing),
      attachmentUrl: _preferNonEmptyUrl(incoming.attachmentUrl, existing.attachmentUrl),
      audioUrl: _preferNonEmptyUrl(incoming.audioUrl, existing.audioUrl),
      attachmentType:
          incoming.attachmentType ?? existing.attachmentType ?? existing.messageType,
      messageType: incoming.messageType ?? existing.messageType,
      // Never regress delivery state due to stale sync snapshots.
      isSent: incoming.isSent || existing.isSent,
      isDelivered: incoming.isMe
          ? incoming.isDelivered
          : (incoming.isDelivered || existing.isDelivered),
      // Outgoing read receipts must follow server truth so ticks can regress.
      isSeen: incoming.isMe
          ? incoming.isSeen
          : (incoming.isSeen || existing.isSeen),
      isRead: incoming.isMe
          ? incoming.isRead
          : (incoming.isRead || existing.isRead),
      // Pending can only stay true if neither sent nor seen yet.
      isPending: incoming.isPending &&
          !(incoming.isSent ||
              incoming.isDelivered ||
              incoming.isSeen ||
              incoming.isRead ||
              existing.isSent ||
              existing.isDelivered ||
              existing.isSeen ||
              existing.isRead),
      attachmentFileName:
          incoming.attachmentFileName ?? existing.attachmentFileName,
      attachmentMimeType:
          incoming.attachmentMimeType ?? existing.attachmentMimeType,
      attachmentSizeBytes:
          incoming.attachmentSizeBytes ?? existing.attachmentSizeBytes,
      editedAt: incoming.editedAt ?? existing.editedAt,
      audioTitle: incoming.audioTitle ?? existing.audioTitle,
      audioArtist: incoming.audioArtist ?? existing.audioArtist,
      audioAlbum: incoming.audioAlbum ?? existing.audioAlbum,
      mediaGroupId: incoming.mediaGroupId ?? existing.mediaGroupId,
      duration: incoming.duration ?? existing.duration,
      localImagePath: incoming.localImagePath ?? existing.localImagePath,
      localFilePath: incoming.localFilePath ?? existing.localFilePath,
    );
  }

  Future<void> _rebuildConversationMetadataInTxn(
    Isar isar,
    String conversationId,
  ) async {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return;

    final latestMessageEntity = await isar.messageEntitys
        .filter()
        .conversationIdEqualTo(normalizedConversationId)
        .sortByCreatedAtDesc()
        .findFirst();

    var conversation = await isar.conversationEntitys
        .filter()
        .idEqualTo(normalizedConversationId)
        .findFirst();

    if (conversation == null && latestMessageEntity == null) {
      return;
    }

    if (conversation == null && latestMessageEntity != null) {
      final latestMessage = latestMessageEntity.toModel();
      conversation = ConversationEntity()
        ..isarId = fastHash(normalizedConversationId)
        ..id = normalizedConversationId
        ..createdAt = latestMessage.createdAt
        ..updatedAt = latestMessage.createdAt
        ..otherUserName = unknownConversationUserLabel
        ..otherUserId = latestMessage.isMe ? null : latestMessage.senderId
        ..otherUserName = _initialOtherUserNameFromMessage(latestMessage)
        ..type = 'private';
    }

    if (conversation == null) return;

    if (latestMessageEntity != null) {
      final latestMessage = latestMessageEntity.toModel();
      conversation
        ..lastMessage = latestMessage.content
        ..lastMessageTime = latestMessage.createdAt
        ..lastMessageType = latestMessage.attachmentType ?? 'text'
        ..isLastMessageFromMe = latestMessage.isMe
        ..lastMessageSenderId = latestMessage.senderId
        ..lastMessageDeliveryStatus =
            _messageDeliveryStatusToString(latestMessage);

      if (latestMessage.createdAt.isAfter(conversation.updatedAt)) {
        conversation.updatedAt = latestMessage.createdAt;
      }
    } else {
      conversation
        ..lastMessage = null
        ..lastMessageTime = null
        ..lastMessageType = null
        ..isLastMessageFromMe = false
        ..lastMessageSenderId = null
        ..lastMessageDeliveryStatus = null;
    }

    final unreadCount = await isar.messageEntitys
        .filter()
        .conversationIdEqualTo(normalizedConversationId)
        .isMeEqualTo(false)
        .isSeenEqualTo(false)
        .isReadEqualTo(false)
        .count();
    conversation.unreadCount = unreadCount;
    conversation.hasUnreadMessages = unreadCount > 0;

    await isar.conversationEntitys.put(conversation);
  }

  Future<void> resetUnreadCount(String conversationId) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();

      if (conversation != null) {
        if (conversation.unreadCount == 0 && !conversation.hasUnreadMessages) {
          return;
        }
        conversation.unreadCount = 0;
        conversation.hasUnreadMessages = false;
        await isar.conversationEntitys.put(conversation);
      }
    });
  }

  Future<void> markOwnMessagesReadUpTo(
    String conversationId,
    DateTime readAt,
  ) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final messages = await isar.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .isMeEqualTo(true)
          .findAll();

      var changed = false;
      for (final msg in messages) {
        if (msg.createdAt.isAfter(readAt)) continue;
        if (msg.isSeen && msg.isRead && msg.isDelivered) continue;
        msg.isSeen = true;
        msg.isRead = true;
        msg.isDelivered = true;
        changed = true;
      }

      if (changed) {
        await isar.messageEntitys.putAll(messages);
        await _rebuildConversationMetadataInTxn(isar, conversationId);
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

      for (final msg in messages) {
        msg.isSeen = true;
        msg.isRead = true;
        msg.isDelivered = true;
      }
      if (messages.isNotEmpty) {
        await isar.messageEntitys.putAll(messages);
      }

      // 2. Reset Unread Count (just to be safe)
      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();

      if (conversation != null) {
        if (conversation.unreadCount == 0 && !conversation.hasUnreadMessages) {
          return;
        }
        conversation.unreadCount = 0;
        conversation.hasUnreadMessages = false;
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
      final messageToDelete =
          await isar.messageEntitys.filter().idEqualTo(messageId).findFirst();
      if (messageToDelete == null) return;

      final conversationId = messageToDelete.conversationId;
      await isar.messageEntitys.filter().idEqualTo(messageId).deleteAll();

      final conversation = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();
      if (conversation == null) return;

      final latestMessageEntity = await isar.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortByCreatedAtDesc()
          .findFirst();

      if (latestMessageEntity != null) {
        final latestMessage = latestMessageEntity.toModel();
        conversation
          ..lastMessage = latestMessage.content
          ..lastMessageTime = latestMessage.createdAt
          ..lastMessageType = latestMessage.attachmentType ?? 'text'
          ..isLastMessageFromMe = latestMessage.isMe
          ..lastMessageSenderId = latestMessage.senderId
          ..lastMessageDeliveryStatus =
              _messageDeliveryStatusToString(latestMessage)
          ..updatedAt = latestMessage.createdAt;
      } else {
        conversation
          ..lastMessage = null
          ..lastMessageTime = null
          ..lastMessageType = null
          ..isLastMessageFromMe = false
          ..lastMessageSenderId = null
          ..lastMessageDeliveryStatus = null;
      }

      final unreadCount = await isar.messageEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .isMeEqualTo(false)
          .isSeenEqualTo(false)
          .isReadEqualTo(false)
          .count();

      conversation.unreadCount = unreadCount;
      conversation.hasUnreadMessages = unreadCount > 0;

      await isar.conversationEntitys.put(conversation);
    });
  }

  Future<void> reconcileMessages(
      String conversationId, List<MessageModel> serverMessages) async {
    final isar = await _dbManager.instance;
    if (serverMessages.isEmpty) {
      await isar.writeTxn(() async {
        await isar.messageEntitys
            .filter()
            .conversationIdEqualTo(conversationId)
            .isPendingEqualTo(false)
            .isFailedEqualTo(false)
            .deleteAll();
        await _rebuildConversationMetadataInTxn(isar, conversationId);
      });
      return;
    }

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
        await isar.messageEntitys
            .filter()
            .anyOf(idsToDelete, (q, id) => q.idEqualTo(id))
            .deleteAll();
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
    await isar.writeTxn(() async {
      final existingById = await _loadExistingConversationsById(
        isar,
        conversations.map((c) => c.id),
      );
      for (final conv in conversations) {
        final existing = existingById[conv.id];
        await isar.conversationEntitys.putIfChanged(
            _mergeConversationEntity(
              conv,
              existing,
              preserveLocalUnread: true,
            ),
            existing);
      }
    });
  }

  Future<void> saveConversation(ConversationModel conversation) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final existing = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversation.id)
          .findFirst();
      await isar.conversationEntitys.putIfChanged(
          _mergeConversationEntity(
            conversation,
            existing,
            preserveLocalUnread: false,
          ),
          existing);
    });
  }

  Future<void> updateConversationProfile({
    required String conversationId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
  }) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      final entity = await isar.conversationEntitys
          .filter()
          .idEqualTo(conversationId)
          .findFirst();
      if (entity == null) return;

      var changed = false;
      final normalizedUserId = otherUserId?.trim();
      if (normalizedUserId != null &&
          normalizedUserId.isNotEmpty &&
          entity.otherUserId != normalizedUserId) {
        entity.otherUserId = normalizedUserId;
        changed = true;
      }

      final normalizedName = otherUserName?.trim();
      if (normalizedName != null &&
          normalizedName.isNotEmpty &&
          entity.otherUserName != normalizedName) {
        entity.otherUserName = normalizedName;
        changed = true;
      }

      final normalizedAvatar = otherUserAvatar?.trim();
      if (normalizedAvatar != null &&
          normalizedAvatar.isNotEmpty &&
          entity.otherUserAvatar != normalizedAvatar) {
        entity.otherUserAvatar = normalizedAvatar;
        changed = true;
      }

      if (changed) {
        await isar.conversationEntitys.put(entity);
      }
    });
  }

  ConversationEntity _mergeConversationEntity(
      ConversationModel incoming, ConversationEntity? existing,
      {required bool preserveLocalUnread}) {
    final merged = ConversationEntity.fromModel(incoming);
    if (existing == null) return merged;

    if (preserveLocalUnread) {
      // unread state is maintained locally by message updates / participant realtime.
      // Prevent stale conversation snapshots from overriding badge counts.
      merged
        ..unreadCount = existing.unreadCount
        ..hasUnreadMessages = existing.hasUnreadMessages;
    }

    if ((merged.otherUserId == null || merged.otherUserId!.trim().isEmpty) &&
        existing.otherUserId != null &&
        existing.otherUserId!.trim().isNotEmpty) {
      merged.otherUserId = existing.otherUserId;
    }

    if (_isUnknownConversationName(merged.otherUserName) &&
        !_isUnknownConversationName(existing.otherUserName)) {
      merged.otherUserName = existing.otherUserName;
    }

    if ((merged.otherUserAvatar == null ||
            merged.otherUserAvatar!.trim().isEmpty) &&
        existing.otherUserAvatar != null &&
        existing.otherUserAvatar!.trim().isNotEmpty) {
      merged.otherUserAvatar = existing.otherUserAvatar;
    }

    // Keep updated_at monotonic in local DB.
    if (existing.updatedAt.isAfter(merged.updatedAt)) {
      merged.updatedAt = existing.updatedAt;
    }

    final existingLast = existing.lastMessageTime;
    final incomingLast = merged.lastMessageTime;
    final incomingHasSender = merged.lastMessageSenderId?.isNotEmpty ?? false;
    final incomingHasStatus =
        merged.lastMessageDeliveryStatus?.isNotEmpty ?? false;
    final incomingStatusRank =
        _deliveryStatusRank(merged.lastMessageDeliveryStatus);
    final existingStatusRank =
        _deliveryStatusRank(existing.lastMessageDeliveryStatus);

    final shouldKeepLocalLastMessage = (existingLast != null &&
            (incomingLast == null || incomingLast.isBefore(existingLast))) ||
        (existingLast != null &&
            incomingLast != null &&
            incomingLast.isAtSameMomentAs(existingLast) &&
            ((!incomingHasSender || !incomingHasStatus) ||
                incomingStatusRank < existingStatusRank));

    if (shouldKeepLocalLastMessage) {
      merged
        ..lastMessage = existing.lastMessage
        ..lastMessageTime = existing.lastMessageTime
        ..lastMessageType = existing.lastMessageType
        ..lastMessageDeliveryStatus = existing.lastMessageDeliveryStatus
        ..isLastMessageFromMe = existing.isLastMessageFromMe
        ..lastMessageSenderId = existing.lastMessageSenderId;
    }

    return merged;
  }

  int _deliveryStatusRank(String? status) {
    switch (status) {
      case 'read':
      case 'seen':
        return 3;
      case 'delivered':
        return 2;
      case 'sent':
        return 1;
      case 'pending':
      case 'failed':
      default:
        return 0;
    }
  }

  String _initialOtherUserNameFromMessage(MessageModel message) {
    if (message.isMe) return unknownConversationUserLabel;
    final senderName = message.senderName?.trim();
    return senderName == null || senderName.isEmpty
        ? unknownConversationUserLabel
        : senderName;
  }

  bool _isUnknownConversationName(String? name) {
    return isUnknownConversationName(name);
  }

  String _messageDeliveryStatusToString(MessageModel message) {
    if (message.isPending == true) return 'pending';
    if (message.isFailed == true) return 'failed';
    if (message.isMe &&
        (message.isSeen == true || message.isRead == true)) {
      return 'read';
    }
    if (message.isDelivered == true) return 'delivered';
    if (message.isSent == true) return 'sent';
    return 'sent';
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

  Future<Map<String, MessageModel>> _loadExistingMessagesById(
    Isar isar,
    Iterable<String> ids,
  ) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) return const <String, MessageModel>{};

    final entities = await isar.messageEntitys
        .filter()
        .anyOf(normalizedIds, (q, id) => q.idEqualTo(id))
        .findAll();
    return <String, MessageModel>{
      for (final entity in entities) entity.id: entity.toModel(),
    };
  }

  Future<Map<String, ConversationEntity>> _loadExistingConversationsById(
    Isar isar,
    Iterable<String> ids,
  ) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) return const <String, ConversationEntity>{};

    final entities = await isar.conversationEntitys
        .filter()
        .anyOf(normalizedIds, (q, id) => q.idEqualTo(id))
        .findAll();
    return <String, ConversationEntity>{
      for (final entity in entities) entity.id: entity,
    };
  }
}

extension on IsarCollection<ConversationEntity> {
  Future<void> putIfChanged(
    ConversationEntity merged,
    ConversationEntity? existing,
  ) async {
    if (existing != null && _isConversationEffectivelySame(existing, merged)) {
      return;
    }
    await put(merged);
  }
}

bool _isConversationEffectivelySame(
  ConversationEntity a,
  ConversationEntity b,
) {
  return a.id == b.id &&
      a.createdAt == b.createdAt &&
      a.updatedAt == b.updatedAt &&
      a.lastMessage == b.lastMessage &&
      a.lastMessageTime == b.lastMessageTime &&
      a.otherUserName == b.otherUserName &&
      a.otherUserAvatar == b.otherUserAvatar &&
      a.otherUserId == b.otherUserId &&
      a.hasUnreadMessages == b.hasUnreadMessages &&
      a.unreadCount == b.unreadCount &&
      a.isPinned == b.isPinned &&
      a.isMuted == b.isMuted &&
      a.isArchived == b.isArchived &&
      a.lastMessageType == b.lastMessageType &&
      a.isLastMessageFromMe == b.isLastMessageFromMe &&
      a.lastMessageSenderId == b.lastMessageSenderId &&
      a.lastMessageDeliveryStatus == b.lastMessageDeliveryStatus &&
      a.type == b.type &&
      a.allowProfileZoom == b.allowProfileZoom &&
      a.otherUserBio == b.otherUserBio &&
      a.otherUserCreatedAt == b.otherUserCreatedAt &&
      a.isBlocked == b.isBlocked &&
      a.isVerified == b.isVerified;
}

bool _isMessageEffectivelySame(MessageModel a, MessageModel b) {
  return a.id == b.id &&
      a.conversationId == b.conversationId &&
      a.senderId == b.senderId &&
      a.content == b.content &&
      a.createdAt == b.createdAt &&
      a.editedAt == b.editedAt &&
      a.attachmentUrl == b.attachmentUrl &&
      a.attachmentType == b.attachmentType &&
      a.attachmentFileName == b.attachmentFileName &&
      a.attachmentMimeType == b.attachmentMimeType &&
      a.attachmentSizeBytes == b.attachmentSizeBytes &&
      a.audioUrl == b.audioUrl &&
      a.audioTitle == b.audioTitle &&
      a.audioArtist == b.audioArtist &&
      a.audioAlbum == b.audioAlbum &&
      a.mediaGroupId == b.mediaGroupId &&
      a.duration == b.duration &&
      a.isRead == b.isRead &&
      a.isSent == b.isSent &&
      a.isDelivered == b.isDelivered &&
      a.isSeen == b.isSeen &&
      a.isPending == b.isPending &&
      a.isFailed == b.isFailed &&
      a.errorMessage == b.errorMessage &&
      a.senderName == b.senderName &&
      a.senderAvatar == b.senderAvatar &&
      a.isMe == b.isMe &&
      a.replyToMessageId == b.replyToMessageId &&
      a.replyToContent == b.replyToContent &&
      a.replyToSenderName == b.replyToSenderName &&
      a.localId == b.localId &&
      a.retryCount == b.retryCount &&
      a.lastRetryTime == b.lastRetryTime &&
      a.messageType == b.messageType &&
      a.deletedGlobally == b.deletedGlobally &&
      _stringListsEqual(a.deletedForUserIds, b.deletedForUserIds) &&
      a.localImagePath == b.localImagePath &&
      a.localFilePath == b.localFilePath &&
      a.uploadProgress == b.uploadProgress &&
      a.isUploading == b.isUploading;
}

bool _stringListsEqual(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
