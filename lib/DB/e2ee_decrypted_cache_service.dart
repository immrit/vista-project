import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'e2ee_decrypted_cache_service.g.dart';

// جدول برای ذخیره پیام‌های رمزگشایی شده
class DecryptedMessages extends Table {
  TextColumn get messageId => text()(); // ID اصلی پیام
  TextColumn get conversationId => text()();
  TextColumn get userId => text()(); // کاربر فعلی
  TextColumn get decryptedContent => text()(); // محتوای رمزگشایی شده
  TextColumn get decryptedReplyContent =>
      text().nullable()(); // محتوای reply رمزگشایی شده
  DateTimeColumn get decryptedAt => dateTime()(); // زمان رمزگشایی
  DateTimeColumn get createdAt => dateTime()(); // زمان ایجاد پیام اصلی

  @override
  Set<Column> get primaryKey => {messageId, conversationId, userId};
}

// تعریف دیتابیس Drift
@DriftDatabase(tables: [DecryptedMessages])
class E2EEDecryptedCacheDatabase extends _$E2EEDecryptedCacheDatabase {
  E2EEDecryptedCacheDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_decrypted_conversation_id ON decrypted_messages (conversation_id);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_decrypted_user_id ON decrypted_messages (user_id);');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_decrypted_message_id ON decrypted_messages (message_id);');
        },
      );

  // ذخیره پیام رمزگشایی شده
  Future<void> cacheDecryptedMessage({
    required String messageId,
    required String conversationId,
    required String userId,
    required String decryptedContent,
    String? decryptedReplyContent,
    required DateTime createdAt,
  }) async {
    try {
      await into(decryptedMessages).insertOnConflictUpdate(
        DecryptedMessagesCompanion.insert(
          messageId: messageId,
          conversationId: conversationId,
          userId: userId,
          decryptedContent: decryptedContent,
          decryptedReplyContent: Value(decryptedReplyContent),
          decryptedAt: DateTime.now(),
          createdAt: createdAt,
        ),
      );
      print('[e2ee_cache] Decrypted message cached: $messageId');
    } catch (e) {
      print('[e2ee_cache] Error caching decrypted message: $e');
    }
  }

  // دریافت پیام رمزگشایی شده
  Future<String?> getDecryptedContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final query = select(decryptedMessages)
        ..where((tbl) =>
            tbl.messageId.equals(messageId) &
            tbl.conversationId.equals(conversationId) &
            tbl.userId.equals(userId));

      final result = await query.getSingleOrNull();
      if (result != null) {
        print('[e2ee_cache] Decrypted content found in cache: $messageId');
        return result.decryptedContent;
      }
      print('[e2ee_cache] No decrypted content found: $messageId');
      return null;
    } catch (e) {
      print('[e2ee_cache] Error getting decrypted content: $e');
      return null;
    }
  }

  // دریافت reply رمزگشایی شده
  Future<String?> getDecryptedReplyContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final query = select(decryptedMessages)
        ..where((tbl) =>
            tbl.messageId.equals(messageId) &
            tbl.conversationId.equals(conversationId) &
            tbl.userId.equals(userId));

      final result = await query.getSingleOrNull();
      if (result != null) {
        print(
            '[e2ee_cache] Decrypted reply content found in cache: $messageId');
        return result.decryptedReplyContent;
      }
      print('[e2ee_cache] No decrypted reply content found: $messageId');
      return null;
    } catch (e) {
      print('[e2ee_cache] Error getting decrypted reply content: $e');
      return null;
    }
  }

  // پاک کردن کش یک مکالمه
  Future<void> clearConversationCache({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await (delete(decryptedMessages)
            ..where((tbl) =>
                tbl.conversationId.equals(conversationId) &
                tbl.userId.equals(userId)))
          .go();
      print('[e2ee_cache] Conversation cache cleared: $conversationId');
    } catch (e) {
      print('[e2ee_cache] Error clearing conversation cache: $e');
    }
  }

  // پاک کردن کش یک پیام خاص
  Future<void> clearMessageCache({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      await (delete(decryptedMessages)
            ..where((tbl) =>
                tbl.messageId.equals(messageId) &
                tbl.conversationId.equals(conversationId) &
                tbl.userId.equals(userId)))
          .go();
      print('[e2ee_cache] Message cache cleared: $messageId');
    } catch (e) {
      print('[e2ee_cache] Error clearing message cache: $e');
    }
  }

  // پاک کردن تمام کش
  Future<void> clearAllCache() async {
    try {
      await delete(decryptedMessages).go();
      print('[e2ee_cache] All decrypted cache cleared');
    } catch (e) {
      print('[e2ee_cache] Error clearing all cache: $e');
    }
  }

  // پاک کردن کش‌های قدیمی
  Future<void> deleteOldCache({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      await (delete(decryptedMessages)
            ..where((tbl) => tbl.decryptedAt.isSmallerThanValue(cutoffDate)))
          .go();
      print('[e2ee_cache] Old cache deleted (older than $daysOld days)');
    } catch (e) {
      print('[e2ee_cache] Error deleting old cache: $e');
    }
  }
}

// اتصال به دیتابیس
QueryExecutor _openConnection() {
  return NativeDatabase.createInBackground(
    File(p.join(
      (Platform.isWindows ? Directory.systemTemp : Directory.systemTemp).path,
      'e2ee_decrypted_cache.sqlite',
    )),
  );
}

// سرویس اصلی
class E2EEDecryptedCacheService {
  static final E2EEDecryptedCacheService _instance =
      E2EEDecryptedCacheService._internal();
  factory E2EEDecryptedCacheService() => _instance;
  E2EEDecryptedCacheService._internal();

  final E2EEDecryptedCacheDatabase _db = E2EEDecryptedCacheDatabase();

  // ذخیره پیام رمزگشایی شده
  Future<void> cacheDecryptedMessage({
    required String messageId,
    required String conversationId,
    required String userId,
    required String decryptedContent,
    String? decryptedReplyContent,
    required DateTime createdAt,
  }) =>
      _db.cacheDecryptedMessage(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
        decryptedContent: decryptedContent,
        decryptedReplyContent: decryptedReplyContent,
        createdAt: createdAt,
      );

  // دریافت پیام رمزگشایی شده
  Future<String?> getDecryptedContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) =>
      _db.getDecryptedContent(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
      );

  // دریافت reply رمزگشایی شده
  Future<String?> getDecryptedReplyContent({
    required String messageId,
    required String conversationId,
    required String userId,
  }) =>
      _db.getDecryptedReplyContent(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
      );

  // پاک کردن کش
  Future<void> clearConversationCache({
    required String conversationId,
    required String userId,
  }) =>
      _db.clearConversationCache(
        conversationId: conversationId,
        userId: userId,
      );

  Future<void> clearMessageCache({
    required String messageId,
    required String conversationId,
    required String userId,
  }) =>
      _db.clearMessageCache(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
      );

  Future<void> clearAllCache() => _db.clearAllCache();
  Future<void> deleteOldCache({int daysOld = 30}) =>
      _db.deleteOldCache(daysOld: daysOld);
}
