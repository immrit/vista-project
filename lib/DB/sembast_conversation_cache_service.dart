import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../model/conversation_model.dart';

class SembastConversationCacheService {
  static Database? _database;
  static bool _isInitialized = false;
  static const String _storeName = 'conversations';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Directory dir;
      if (Platform.isAndroid || Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getTemporaryDirectory();
      }

      final dbPath = '${dir.path}/conversation_cache.db';
      _database = await databaseFactoryIo.openDatabase(dbPath);

      _isInitialized = true;
      print('✅ Sembast Conversation Cache initialized successfully');
    } catch (e) {
      print('❌ Error initializing Sembast Conversation Cache: $e');
      rethrow;
    }
  }

  static Database get _db {
    if (_database == null) {
      throw Exception('Sembast not initialized. Call initialize() first.');
    }
    return _database!;
  }

  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>.main();

  /// Cache a conversation
  Future<void> cacheConversation(
      ConversationModel conversation, String userId) async {
    try {
      final key = '${conversation.id}_$userId';
      final data = _conversationToMap(conversation);
      await _store.record(key).put(_db, data);
    } catch (e) {
      print('❌ Error caching conversation: $e');
      rethrow;
    }
  }

  /// Get all cached conversations
  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    try {
      final records = await _store.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key as String;
            return key.endsWith('_$userId');
          }),
        ),
      );

      final conversations =
          records.map((record) => _mapToConversation(record.value)).toList();

      // Sort by lastMessageTime descending
      conversations.sort((a, b) => (b.lastMessageTime ?? DateTime(1970))
          .compareTo(a.lastMessageTime ?? DateTime(1970)));
      return conversations;
    } catch (e) {
      print('❌ Error getting cached conversations: $e');
      return [];
    }
  }

  /// Watch cached conversations (stream)
  Stream<List<ConversationModel>> watchCachedConversations(
      String userId) async* {
    try {
      // For now, we'll use a simple approach - periodically fetch conversations
      // Sembast doesn't have a direct equivalent to onSnapshots for multiple records
      while (true) {
        final conversations = await getCachedConversations(userId);
        yield conversations;
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error watching cached conversations: $e');
      yield [];
    }
  }

  /// Get a specific conversation
  Future<ConversationModel?> getConversation(
      String conversationId, String userId) async {
    try {
      final key = '${conversationId}_$userId';
      final record = await _store.record(key).get(_db);
      if (record != null) {
        return _mapToConversation(record);
      }
      return null;
    } catch (e) {
      print('❌ Error getting conversation: $e');
      return null;
    }
  }

  /// Update a conversation
  Future<void> updateConversation(
      ConversationModel conversation, String userId) async {
    try {
      final key = '${conversation.id}_$userId';
      final data = _conversationToMap(conversation);
      await _store.record(key).put(_db, data);
    } catch (e) {
      print('❌ Error updating conversation: $e');
      rethrow;
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId, String userId) async {
    try {
      final key = '${conversationId}_$userId';
      await _store.record(key).delete(_db);
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Clear all cached conversations
  Future<void> clearAllCache() async {
    try {
      await _store.delete(_db);
    } catch (e) {
      print('❌ Error clearing all conversations: $e');
      rethrow;
    }
  }

  /// Get conversations by type
  Future<List<ConversationModel>> getConversationsByType(
      String conversationType, String userId) async {
    try {
      final conversations = await getCachedConversations(userId);
      // For now, return all conversations since ConversationModel doesn't have conversationType
      return conversations;
    } catch (e) {
      print('❌ Error getting conversations by type: $e');
      return [];
    }
  }

  /// Get pinned conversations
  Future<List<ConversationModel>> getPinnedConversations(String userId) async {
    try {
      final conversations = await getCachedConversations(userId);
      return conversations.where((c) => c.isPinned).toList();
    } catch (e) {
      print('❌ Error getting pinned conversations: $e');
      return [];
    }
  }

  /// Get archived conversations
  Future<List<ConversationModel>> getArchivedConversations(
      String userId) async {
    try {
      final conversations = await getCachedConversations(userId);
      return conversations.where((c) => c.isArchived).toList();
    } catch (e) {
      print('❌ Error getting archived conversations: $e');
      return [];
    }
  }

  /// Search conversations
  Future<List<ConversationModel>> searchConversations(
      String query, String userId) async {
    try {
      final conversations = await getCachedConversations(userId);
      return conversations
          .where((c) => (c.otherUserName ?? '')
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('❌ Error searching conversations: $e');
      return [];
    }
  }

  /// Update conversation last message
  Future<void> updateLastMessage(
      String conversationId,
      String messageId,
      String content,
      String senderId,
      String senderName,
      DateTime timestamp) async {
    try {
      final conversation = await getConversation(conversationId, '');
      if (conversation != null) {
        // Create a new conversation with updated last message
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: timestamp,
          lastMessage: content,
          lastMessageTime: timestamp,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: conversation.hasUnreadMessages,
          unreadCount: conversation.unreadCount,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, '');
      }
    } catch (e) {
      print('❌ Error updating last message: $e');
      rethrow;
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      final conversation = await getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: false,
          unreadCount: 0,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, userId);
      }
    } catch (e) {
      print('❌ Error marking conversation as read: $e');
      rethrow;
    }
  }

  /// Increment unread count
  Future<void> incrementUnreadCount(
      String conversationId, String userId) async {
    try {
      final conversation = await getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: true,
          unreadCount: conversation.unreadCount + 1,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, userId);
      }
    } catch (e) {
      print('❌ Error incrementing unread count: $e');
      rethrow;
    }
  }

  /// Convert ConversationModel to Map
  Map<String, dynamic> _conversationToMap(ConversationModel conversation) {
    return {
      'id': conversation.id,
      'createdAt': conversation.createdAt.toIso8601String(),
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'lastMessage': conversation.lastMessage,
      'lastMessageTime': conversation.lastMessageTime?.toIso8601String(),
      'participants': conversation.participants.map((p) => p.toJson()).toList(),
      'otherUserName': conversation.otherUserName,
      'otherUserAvatar': conversation.otherUserAvatar,
      'otherUserId': conversation.otherUserId,
      'hasUnreadMessages': conversation.hasUnreadMessages,
      'unreadCount': conversation.unreadCount,
      'isPinned': conversation.isPinned,
      'isMuted': conversation.isMuted,
      'isArchived': conversation.isArchived,
    };
  }

  /// Convert Map to ConversationModel
  ConversationModel _mapToConversation(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'])
          : null,
      participants: (map['participants'] as List<dynamic>?)
              ?.map<ConversationParticipantModel>(
                  (p) => ConversationParticipantModel.fromJson(p))
              .toList() ??
          [],
      otherUserName: map['otherUserName'],
      otherUserAvatar: map['otherUserAvatar'],
      otherUserId: map['otherUserId'],
      hasUnreadMessages: map['hasUnreadMessages'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
      isPinned: map['isPinned'] ?? false,
      isMuted: map['isMuted'] ?? false,
      isArchived: map['isArchived'] ?? false,
    );
  }

  /// Watch a specific conversation
  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) async* {
    try {
      final key = '${conversationId}_$userId';
      await for (final snapshot in _store.record(key).onSnapshot(_db)) {
        if (snapshot != null) {
          yield _mapToConversation(snapshot.value);
        } else {
          yield null;
        }
      }
    } catch (e) {
      print('❌ Error watching conversation: $e');
      yield null;
    }
  }

  /// Get conversation synchronously
  ConversationModel? getConversationSync(String conversationId) {
    try {
      final key = '${conversationId}_';
      final record = _store.record(key).getSync(_db);
      if (record != null) {
        return _mapToConversation(record);
      }
      return null;
    } catch (e) {
      print('❌ Error getting conversation sync: $e');
      return null;
    }
  }

  /// Update last read
  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    try {
      final conversation = await getConversation(conversationId, '');
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: conversation.hasUnreadMessages,
          unreadCount: conversation.unreadCount,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, '');
      }
    } catch (e) {
      print('❌ Error updating last read: $e');
      rethrow;
    }
  }

  /// Remove conversation
  Future<void> removeConversation(String conversationId, String userId) async {
    await deleteConversation(conversationId, userId);
  }

  /// Set pin status
  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    try {
      final conversation = await getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: conversation.hasUnreadMessages,
          unreadCount: conversation.unreadCount,
          isPinned: isPinned,
          isMuted: conversation.isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, userId);
      }
    } catch (e) {
      print('❌ Error setting pin status: $e');
      rethrow;
    }
  }

  /// Set mute status
  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    try {
      final conversation = await getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: conversation.hasUnreadMessages,
          unreadCount: conversation.unreadCount,
          isPinned: conversation.isPinned,
          isMuted: isMuted,
          isArchived: conversation.isArchived,
        );
        await updateConversation(updatedConversation, userId);
      }
    } catch (e) {
      print('❌ Error setting mute status: $e');
      rethrow;
    }
  }

  /// Set archive status
  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    try {
      final conversation = await getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = ConversationModel(
          id: conversation.id,
          createdAt: conversation.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: conversation.lastMessage,
          lastMessageTime: conversation.lastMessageTime,
          participants: conversation.participants,
          otherUserName: conversation.otherUserName,
          otherUserAvatar: conversation.otherUserAvatar,
          otherUserId: conversation.otherUserId,
          hasUnreadMessages: conversation.hasUnreadMessages,
          unreadCount: conversation.unreadCount,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
          isArchived: isArchived,
        );
        await updateConversation(updatedConversation, userId);
      }
    } catch (e) {
      print('❌ Error setting archive status: $e');
      rethrow;
    }
  }

  /// Clear cache for specific user
  Future<void> clearCache(String userId) async {
    try {
      final records = await _store.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key as String;
            return key.endsWith('_$userId');
          }),
        ),
      );

      for (final record in records) {
        await _store.record(record.key).delete(_db);
      }
    } catch (e) {
      print('❌ Error clearing cache for user: $e');
      rethrow;
    }
  }

  /// Close database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
}
