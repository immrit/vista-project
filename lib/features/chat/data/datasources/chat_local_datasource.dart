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
  Stream<List<MessageModel>> watchMessages(
      String conversationId, String currentUserId) async* {
    final db = await _dbManager.getChatDatabase();

    // فیلتر کردن پیام‌های مربوط به این چت و مرتب‌سازی
    final finder = Finder(
      filter: Filter.equals('conversation_id', conversationId),
      sortOrders: [SortOrder('created_at', false)], // جدیدترین اول
    );

    yield* _messageStore.query(finder: finder).onSnapshots(db).map((snapshots) {
      return snapshots.map((snapshot) {
        // تبدیل رکورد دیتابیس به مدل
        return MessageModel.fromJson(snapshot.value,
            currentUserId: currentUserId);
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

  /// دریافت یک پیام از دیتابیس لوکال
  Future<MessageModel?> getMessage(String messageId, String currentUserId) async {
    final db = await _dbManager.getChatDatabase();
    final snapshot = await _messageStore.record(messageId).getSnapshot(db);
    if (snapshot != null) {
      return MessageModel.fromJson(snapshot.value, currentUserId: currentUserId);
    }
    return null;
  }

  /// حذف پیام
  Future<void> deleteMessage(String messageId) async {
    final db = await _dbManager.getChatDatabase();
    await _messageStore.record(messageId).delete(db);
  }

  /// 🔹 متد جدید: همگام‌سازی هوشمند (Reconciliation)
  /// این متد لیست پیام‌های سرور را می‌گیرد و هر پیامی در لوکال که
  /// در بازه زمانی این لیست قرار دارد اما در لیست سرور نیست را حذف می‌کند.
  Future<void> reconcileMessages(String conversationId, List<MessageModel> serverMessages) async {
    if (serverMessages.isEmpty) return;

    final db = await _dbManager.getChatDatabase();

    // 1. پیدا کردن محدوده زمانی پیام‌های دریافتی (از قدیمی‌ترین تا جدیدترین)
    // برای اطمینان، کمی بازه را بازتر می‌گیریم
    final sortedServer = List<MessageModel>.from(serverMessages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    final oldestServerDate = sortedServer.first.createdAt;
    
    // 2. گرفتن تمام پیام‌های لوکال در این بازه زمانی و بالاتر
    // یعنی پیام‌هایی که باید در این لیست سرور باشند
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('conversation_id', conversationId),
        Filter.greaterThanOrEquals('created_at', oldestServerDate.toIso8601String()),
      ]),
    );

    final localSnapshots = await _messageStore.find(db, finder: finder);
    final localIds = localSnapshots.map((e) => e.key).toSet();
    final serverIds = serverMessages.map((m) => m.id).toSet();

    // 3. شناسایی پیام‌های حذف شده (در لوکال هست ولی در سرور نیست)
    final idsToDelete = localIds.difference(serverIds).toList();

    if (idsToDelete.isNotEmpty) {
      print('♻️ Sync Cleanup: Deleting ${idsToDelete.length} ghost messages locally.');
      
      // حذف دسته‌ای پیام‌های یتیم
      await _messageStore.records(idsToDelete).delete(db);
    }
    
    // 4. ذخیره پیام‌های جدید یا آپدیت شده سرور
    await saveMessages(serverMessages);
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

  Stream<List<ConversationModel>> watchConversations(
      String currentUserId) async* {
    final db = await _dbManager.getChatDatabase();

    final finder = Finder(
      sortOrders: [SortOrder('updated_at', false)],
    );

    yield* _conversationStore
        .query(finder: finder)
        .onSnapshots(db)
        .map((snapshots) {
      return snapshots.map((snapshot) {
        return ConversationModel.fromJson(snapshot.value,
            currentUserId: currentUserId);
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
    await _conversationStore
        .record(conversation.id)
        .put(db, conversation.toJson());
  }

  Future<ConversationModel?> getConversation(
      String conversationId, String currentUserId) async {
    final db = await _dbManager.getChatDatabase();
    final snapshot =
        await _conversationStore.record(conversationId).getSnapshot(db);
    if (snapshot != null) {
      return ConversationModel.fromJson(snapshot.value,
          currentUserId: currentUserId);
    }
    return null;
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await _dbManager.getChatDatabase();
    await _conversationStore.record(conversationId).delete(db);
  }
}
