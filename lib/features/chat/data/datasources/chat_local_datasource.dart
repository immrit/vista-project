// lib/features/chat/data/datasources/chat_local_datasource.dart

import 'package:sembast/sembast.dart';
import '../../../../model/message_model.dart';
import '../../../../model/conversation_model.dart';
import '../../../../DB/database_manager.dart';

class ChatLocalDataSource {
  final DatabaseManager _dbManager;

  // تعریف Store ها (مثل جداول در SQL)
  final _messageStore = stringMapStoreFactory.store('messages');
  final _conversationStore = stringMapStoreFactory.store('conversations');

  ChatLocalDataSource(this._dbManager);

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES OPERTAIONS
  // ═══════════════════════════════════════════════════════════════════

  /// استریم پیام‌های یک مکالمه (بدون درگیری با شبکه)
  /// این متد قلب تپنده چت است. هر تغییری در دیتابیس فوراً اینجا دیده می‌شود.
  Stream<List<MessageModel>> watchMessages(String conversationId, String currentUserId) async* {
    final db = await _dbManager.getChatDatabase();

    // فیلتر کردن پیام‌های مربوط به این چت و مرتب‌سازی
    final finder = Finder(
      filter: Filter.equals('conversation_id', conversationId),
      sortOrders: [SortOrder('created_at', false)], // جدیدترین اول
    );

    yield* _messageStore.query(finder: finder).onSnapshots(db).map((snapshots) {
      return snapshots.map((snapshot) {
        // تبدیل رکورد دیتابیس به مدل
        return MessageModel.fromJson(snapshot.value, currentUserId: currentUserId);
      }).toList();
    });
  }

  /// ذخیره یا آپدیت لیست پیام‌ها (Bulk Insert/Update)
  Future<void> saveMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    final db = await _dbManager.getChatDatabase();

    await db.transaction((txn) async {
      for (var message in messages) {
        await _messageStore.record(message.id).put(txn, message.toJson());
      }
    });
  }

  /// ذخیره یک پیام تکی (مثلاً موقع ارسال)
  Future<void> saveMessage(MessageModel message) async {
    final db = await _dbManager.getChatDatabase();
    await _messageStore.record(message.id).put(db, message.toJson());
  }

  /// حذف پیام
  Future<void> deleteMessage(String messageId) async {
    final db = await _dbManager.getChatDatabase();
    await _messageStore.record(messageId).delete(db);
  }

  /// پاک کردن پیام‌های یک مکالمه
  Future<void> clearMessages(String conversationId) async {
    final db = await _dbManager.getChatDatabase();
    await _messageStore.delete(
      db,
      finder: Finder(filter: Filter.equals('conversation_id', conversationId)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  Stream<List<ConversationModel>> watchConversations(String currentUserId) async* {
    final db = await _dbManager.getChatDatabase();

    final finder = Finder(
      sortOrders: [SortOrder('updated_at', false)],
    );

    yield* _conversationStore.query(finder: finder).onSnapshots(db).map((snapshots) {
      return snapshots.map((snapshot) {
        return ConversationModel.fromJson(snapshot.value, currentUserId: currentUserId);
      }).toList();
    });
  }

  Future<void> saveConversations(List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return;
    final db = await _dbManager.getChatDatabase();
    await db.transaction((txn) async {
      for (var conv in conversations) {
        await _conversationStore.record(conv.id).put(txn, conv.toJson());
      }
    });
  }

  Future<void> saveConversation(ConversationModel conversation) async {
    final db = await _dbManager.getChatDatabase();
    await _conversationStore.record(conversation.id).put(db, conversation.toJson());
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await _dbManager.getChatDatabase();
    await _conversationStore.record(conversationId).delete(db);
  }
}
