import 'package:sembast/sembast.dart' show Database, StoreRef;
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../model/message_model.dart';

class SembastMessageCacheService {
  static Database? _database;
  static bool _isInitialized = false;
  static const String _storeName = 'messages';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Directory dir;
      if (Platform.isAndroid || Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getTemporaryDirectory();
      }

      final dbPath = '${dir.path}/message_cache.db';
      _database = await databaseFactoryIo.openDatabase(dbPath);

      _isInitialized = true;
      print('✅ Sembast Message Cache initialized successfully');
    } catch (e) {
      print('❌ Error initializing Sembast Message Cache: $e');
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

  /// Cache a message
  Future<void> cacheMessage(MessageModel message, String userId) async {
    try {
      final key = '${message.conversationId}_${message.id}';
      final data = _messageToMap(message);
      await _store.record(key).put(_db, data);
    } catch (e) {
      print('❌ Error caching message: $e');
      rethrow;
    }
  }

  /// Cache multiple messages
  Future<void> cacheMessages(List<MessageModel> messages, String userId) async {
    try {
      await _db.transaction((txn) async {
        for (final message in messages) {
          final key = '${message.conversationId}_${message.id}';
          final data = _messageToMap(message);
          await _store.record(key).put(txn, data);
        }
      });
    } catch (e) {
      print('❌ Error caching messages: $e');
      rethrow;
    }
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>> getCachedMessages(
      String conversationId, String userId) async {
    try {
      final records = await _store.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key as String;
            return key.startsWith('${conversationId}_');
          }),
        ),
      );

      final messages =
          records.map((record) => _mapToMessage(record.value)).toList();

      // Sort by createdAt descending
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return messages;
    } catch (e) {
      print('❌ Error getting cached messages: $e');
      return [];
    }
  }

  /// Get conversation messages with limit
  Future<List<MessageModel>> getConversationMessages(
      String conversationId, String userId,
      {int? limit}) async {
    try {
      final messages = await getCachedMessages(conversationId, userId);
      if (limit != null && limit > 0) {
        return messages.take(limit).toList();
      }
      return messages;
    } catch (e) {
      print('❌ Error getting conversation messages: $e');
      return [];
    }
  }

  /// Get a specific message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId, String userId) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      if (record != null) {
        return _mapToMessage(record);
      }
      return null;
    } catch (e) {
      print('❌ Error getting message: $e');
      return null;
    }
  }

  /// Update a message
  Future<void> updateMessage(MessageModel message, String userId) async {
    try {
      final key = '${message.conversationId}_${message.id}';
      final data = _messageToMap(message);
      await _store.record(key).put(_db, data);
    } catch (e) {
      print('❌ Error updating message: $e');
      rethrow;
    }
  }

  /// Replace temporary message with actual message
  Future<void> replaceTempMessage(
      MessageModel tempMessage, MessageModel actualMessage) async {
    try {
      await _db.transaction((txn) async {
        // Delete temp message
        final tempKey = '${tempMessage.conversationId}_${tempMessage.id}';
        await _store.record(tempKey).delete(txn);

        // Add actual message
        final actualKey = '${actualMessage.conversationId}_${actualMessage.id}';
        final data = _messageToMap(actualMessage);
        await _store.record(actualKey).put(txn, data);
      });
    } catch (e) {
      print('❌ Error replacing temp message: $e');
      rethrow;
    }
  }

  /// Mark message as failed
  Future<void> markMessageAsFailed(
      String conversationId, String messageId) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      if (record != null) {
        record['isFailed'] = true;
        record['status'] = 'failed';
        record['updatedAt'] = DateTime.now().toIso8601String();
        await _store.record(key).put(_db, record);
      }
    } catch (e) {
      print('❌ Error marking message as failed: $e');
      rethrow;
    }
  }

  /// Clear messages for a conversation
  Future<void> clearConversationMessages(
      String conversationId, String userId) async {
    try {
      final records = await _store.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key as String;
            return key.startsWith('${conversationId}_');
          }),
        ),
      );

      await _db.transaction((txn) async {
        for (final record in records) {
          await _store.record(record.key).delete(txn);
        }
      });
    } catch (e) {
      print('❌ Error clearing conversation messages: $e');
      rethrow;
    }
  }

  /// Clear a specific message
  Future<void> clearMessage(
      String conversationId, String messageId, String userId) async {
    try {
      final key = '${conversationId}_$messageId';
      await _store.record(key).delete(_db);
    } catch (e) {
      print('❌ Error clearing message: $e');
      rethrow;
    }
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    try {
      await _store.delete(_db);
    } catch (e) {
      print('❌ Error clearing all cache: $e');
      rethrow;
    }
  }

  /// Delete messages older than specified date
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    try {
      final records = await _store.find(_db);
      await _db.transaction((txn) async {
        for (final record in records) {
          final message = _mapToMessage(record.value);
          if (message.createdAt.isBefore(date)) {
            await _store.record(record.key).delete(txn);
          }
        }
      });
    } catch (e) {
      print('❌ Error deleting old messages: $e');
      rethrow;
    }
  }

  /// Count unread messages
  Future<int> countUnreadMessages(String conversationId) async {
    try {
      final records = await _store.find(
        _db,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key as String;
            return key.startsWith('${conversationId}_');
          }),
        ),
      );

      int count = 0;
      for (final record in records) {
        final message = _mapToMessage(record.value);
        if (!message.isRead) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('❌ Error counting unread messages: $e');
      return 0;
    }
  }

  /// Perform transaction
  Future<void> performTransaction(Future<void> Function() action) async {
    try {
      await _db.transaction((txn) async {
        await action();
      });
    } catch (e) {
      print('❌ Error in transaction: $e');
      rethrow;
    }
  }

  /// Convert MessageModel to Map
  Map<String, dynamic> _messageToMap(MessageModel message) {
    return {
      'id': message.id,
      'conversationId': message.conversationId,
      'senderId': message.senderId,
      'content': message.content,
      'createdAt': message.createdAt.toIso8601String(),
      'attachmentUrl': message.attachmentUrl,
      'attachmentType': message.attachmentType,
      'isRead': message.isRead,
      'isSent': message.isSent,
      'senderName': message.senderName,
      'senderAvatar': message.senderAvatar,
      'isMe': message.isMe,
      'replyToMessageId': message.replyToMessageId,
      'replyToContent': message.replyToContent,
      'replyToSenderName': message.replyToSenderName,
      'isPending': message.isPending,
      'localId': message.localId,
      'retryCount': message.retryCount,
    };
  }

  /// Convert Map to MessageModel
  MessageModel _mapToMessage(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      attachmentUrl: map['attachmentUrl'],
      attachmentType: map['attachmentType'],
      isRead: map['isRead'] ?? false,
      isSent: map['isSent'] ?? true,
      senderName: map['senderName'],
      senderAvatar: map['senderAvatar'],
      isMe: map['isMe'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToContent: map['replyToContent'],
      replyToSenderName: map['replyToSenderName'],
      isPending: map['isPending'] ?? false,
      localId: map['localId'],
      retryCount: map['retryCount'] ?? 0,
    );
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
