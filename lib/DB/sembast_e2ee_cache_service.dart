import 'package:sembast/sembast.dart' show Database, StoreRef;
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class SembastE2EECacheService {
  static Database? _database;
  static bool _isInitialized = false;
  static const String _storeName = 'e2ee_decrypted';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Directory dir;
      if (Platform.isAndroid || Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getTemporaryDirectory();
      }

      final dbPath = '${dir.path}/e2ee_cache.db';
      _database = await databaseFactoryIo.openDatabase(dbPath);

      _isInitialized = true;
      print('✅ Sembast E2EE Cache initialized successfully');
    } catch (e) {
      print('❌ Error initializing Sembast E2EE Cache: $e');
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

  /// Cache a decrypted message
  Future<void> cacheDecryptedMessage({
    required String messageId,
    required String conversationId,
    required String decryptedContent,
    String? encryptionKey,
    DateTime? decryptedAt,
    DateTime? createdAt,
    String? metadata,
    bool isVerified = false,
    String? signature,
    String? algorithm,
    int? keyVersion,
  }) async {
    try {
      final key = '${conversationId}_$messageId';
      final data = {
        'messageId': messageId,
        'conversationId': conversationId,
        'decryptedContent': decryptedContent,
        'encryptionKey': encryptionKey ?? '',
        'decryptedAt':
            (decryptedAt ?? createdAt ?? DateTime.now()).toIso8601String(),
        'metadata': metadata,
        'isVerified': isVerified,
        'signature': signature,
        'algorithm': algorithm,
        'keyVersion': keyVersion,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _store.record(key).put(_db, data);
    } catch (e) {
      print('❌ Error caching decrypted message: $e');
      rethrow;
    }
  }

  /// Get decrypted message
  Future<String?> getDecryptedMessage(
      String messageId, String conversationId) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      if (record != null) {
        return record['decryptedContent'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting decrypted message: $e');
      return null;
    }
  }

  /// Get decrypted content with userId parameter (for compatibility)
  Future<String?> getDecryptedContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    return await getDecryptedMessage(messageId, conversationId);
  }

  /// Get decrypted reply content (placeholder)
  Future<String?> getDecryptedReplyContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    // This is a placeholder - reply content is stored in the same record
    return await getDecryptedMessage(messageId, conversationId);
  }

  /// Clear conversation cache (placeholder)
  Future<void> clearConversationCache({
    required String conversationId,
    required String userId,
  }) async {
    await clearConversationDecryptedMessages(conversationId);
  }

  /// Clear message cache (placeholder)
  Future<void> clearMessageCache({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    await deleteDecryptedMessage(messageId, conversationId);
  }

  /// Clear all cache (placeholder)
  Future<void> clearAllCache() async {
    await clearAllDecryptedMessages();
  }

  /// Delete old cache (placeholder)
  Future<void> deleteOldCache({int daysOld = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    await deleteOldDecryptedMessages(cutoffDate);
  }

  /// Get decrypted message with full data
  Future<Map<String, dynamic>?> getDecryptedMessageData(
      String messageId, String conversationId) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      return record;
    } catch (e) {
      print('❌ Error getting decrypted message data: $e');
      return null;
    }
  }

  /// Check if message is decrypted
  Future<bool> isMessageDecrypted(
      String messageId, String conversationId) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      return record != null;
    } catch (e) {
      print('❌ Error checking if message is decrypted: $e');
      return false;
    }
  }

  /// Get all decrypted messages for a conversation
  Future<List<Map<String, dynamic>>> getDecryptedMessagesForConversation(
      String conversationId) async {
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

      return records.map((record) => record.value).toList();
    } catch (e) {
      print('❌ Error getting decrypted messages for conversation: $e');
      return [];
    }
  }

  /// Delete decrypted message
  Future<void> deleteDecryptedMessage(
      String messageId, String conversationId) async {
    try {
      final key = '${conversationId}_$messageId';
      await _store.record(key).delete(_db);
    } catch (e) {
      print('❌ Error deleting decrypted message: $e');
      rethrow;
    }
  }

  /// Clear all decrypted messages for a conversation
  Future<void> clearConversationDecryptedMessages(String conversationId) async {
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
      print('❌ Error clearing conversation decrypted messages: $e');
      rethrow;
    }
  }

  /// Clear all decrypted messages
  Future<void> clearAllDecryptedMessages() async {
    try {
      await _store.delete(_db);
    } catch (e) {
      print('❌ Error clearing all decrypted messages: $e');
      rethrow;
    }
  }

  /// Delete old decrypted messages
  Future<void> deleteOldDecryptedMessages(DateTime olderThan) async {
    try {
      final records = await _store.find(_db);
      await _db.transaction((txn) async {
        for (final record in records) {
          final decryptedAt =
              DateTime.tryParse(record.value['decryptedAt'] ?? '');
          if (decryptedAt != null && decryptedAt.isBefore(olderThan)) {
            await _store.record(record.key).delete(txn);
          }
        }
      });
    } catch (e) {
      print('❌ Error deleting old decrypted messages: $e');
      rethrow;
    }
  }

  /// Get decrypted messages count
  Future<int> getDecryptedMessagesCount() async {
    try {
      return await _store.count(_db);
    } catch (e) {
      print('❌ Error getting decrypted messages count: $e');
      return 0;
    }
  }

  /// Get decrypted messages count for conversation
  Future<int> getDecryptedMessagesCountForConversation(
      String conversationId) async {
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
      return records.length;
    } catch (e) {
      print('❌ Error getting decrypted messages count for conversation: $e');
      return 0;
    }
  }

  /// Update decrypted message verification status
  Future<void> updateVerificationStatus(String messageId, String conversationId,
      bool isVerified, String? signature) async {
    try {
      final key = '${conversationId}_$messageId';
      final record = await _store.record(key).get(_db);
      if (record != null) {
        record['isVerified'] = isVerified;
        record['signature'] = signature;
        record['updatedAt'] = DateTime.now().toIso8601String();
        await _store.record(key).put(_db, record);
      }
    } catch (e) {
      print('❌ Error updating verification status: $e');
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
