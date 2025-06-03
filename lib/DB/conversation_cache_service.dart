// conversation_cache_service.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../model/conversation_model.dart';

part 'conversation_cache_service.g.dart';

class CachedConversations extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastMessage => text().nullable()();
  DateTimeColumn get lastMessageTime => dateTime().nullable()();
  TextColumn get otherUserName => text().nullable()();
  TextColumn get otherUserAvatar => text().nullable()();
  TextColumn get otherUserId => text().nullable()();
  BoolColumn get hasUnreadMessages =>
      boolean().withDefault(const Constant(false))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedConversations])
class ConversationCacheDatabase extends _$ConversationCacheDatabase {
  ConversationCacheDatabase() : super(_openConnection());
  @override
  int get schemaVersion => 1;

  Future<void> cacheConversation(ConversationModel conversation) async {
    await into(cachedConversations).insertOnConflictUpdate(
      CachedConversationsCompanion(
        id: Value(conversation.id),
        createdAt: Value(conversation.createdAt),
        updatedAt: Value(conversation.updatedAt),
        lastMessage: Value(conversation.lastMessage),
        lastMessageTime: Value(conversation.lastMessageTime),
        otherUserName: Value(conversation.otherUserName),
        otherUserAvatar: Value(conversation.otherUserAvatar),
        otherUserId: Value(conversation.otherUserId),
        hasUnreadMessages: Value(conversation.hasUnreadMessages),
        unreadCount: Value(conversation.unreadCount),
      ),
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await (delete(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .go();
  }

  Future<List<ConversationModel>> getCachedConversations() async {
    final rows = await select(cachedConversations).get();
    return rows
        .map((row) => ConversationModel(
              id: row.id,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
              lastMessage: row.lastMessage,
              lastMessageTime: row.lastMessageTime,
              otherUserName: row.otherUserName,
              otherUserAvatar: row.otherUserAvatar,
              otherUserId: row.otherUserId,
              hasUnreadMessages: row.hasUnreadMessages,
              unreadCount: row.unreadCount,
              participants: [],
            ))
        .toList();
  }

  // متد جدید: بروزرسانی یا درج مکالمه
  Future<void> updateConversation(ConversationModel conversation) async {
    await cacheConversation(conversation);
  }

  // متد جدید: دریافت یک مکالمه با آیدی
  Future<ConversationModel?> getConversation(String conversationId) async {
    final row = await (select(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .getSingleOrNull();
    if (row == null) return null;
    return ConversationModel(
      id: row.id,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastMessage: row.lastMessage,
      lastMessageTime: row.lastMessageTime,
      otherUserName: row.otherUserName,
      otherUserAvatar: row.otherUserAvatar,
      otherUserId: row.otherUserId,
      hasUnreadMessages: row.hasUnreadMessages,
      unreadCount: row.unreadCount,
      participants: [],
    );
  }

  // متد جدید: پاک کردن کل کش مکالمات
  Future<void> clearCache() async {
    await delete(cachedConversations).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'conversations.sqlite'));
    return NativeDatabase(dbFile);
  });
}

// ConversationCacheService: سرویس ساده برای استفاده از دیتابیس Drift
class ConversationCacheService {
  static final ConversationCacheService _instance =
      ConversationCacheService._internal();
  factory ConversationCacheService() => _instance;
  ConversationCacheService._internal();

  final ConversationCacheDatabase _db = ConversationCacheDatabase();

  Future<void> cacheConversation(ConversationModel conversation) =>
      _db.cacheConversation(conversation);

  Future<List<ConversationModel>> getCachedConversations() =>
      _db.getCachedConversations();

  // اضافه شد: بروزرسانی یا درج مکالمه
  Future<void> updateConversation(ConversationModel conversation) =>
      _db.updateConversation(conversation);

  // اضافه شد: دریافت یک مکالمه با آیدی
  Future<ConversationModel?> getConversation(String conversationId) =>
      _db.getConversation(conversationId);

  // اضافه شد: پاک کردن کل کش مکالمات
  Future<void> clearCache() => _db.clearCache();

  Future<void> removeConversation(String conversationId) async {
    await _db.deleteConversation(conversationId);
  }

  // متد سینک برای گرفتن مکالمه از کش حافظه (Drift) بدون async
  ConversationModel? getConversationSync(String conversationId) {
    // Drift فقط متد async دارد، اما می‌توانیم یک کش ساده در حافظه نگه داریم (در صورت نیاز)
    // یا این متد را فقط برای سازگاری با کد فراخوانی‌کننده قرار دهیم و همیشه null برگردانیم
    // یا یک هشدار لاگ کنیم
    // اگر نیاز به کش حافظه داری، باید آن را اضافه کنی
    return null;
  }

  // سایر متدهای مورد نیاز را می‌توان اضافه کرد
}
