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
  TextColumn get userId => text()(); // اضافه شد: userId برای هر مکالمه
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
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id, userId}; // کلید ترکیبی
}

@DriftDatabase(tables: [CachedConversations])
class ConversationCacheDatabase extends _$ConversationCacheDatabase {
  ConversationCacheDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5; // نسخه را افزایش دادیم

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(cachedConversations, cachedConversations.isPinned);
        }
        if (from < 3) {
          await m.addColumn(cachedConversations, cachedConversations.isMuted);
        }
        if (from < 4) {
          await m.addColumn(
              cachedConversations, cachedConversations.isArchived);
        }
        if (from < 5) {
          await m.addColumn(cachedConversations, cachedConversations.userId);
        }
      },
    );
  }

  // ذخیره مکالمه برای کاربر خاص
  Future<void> cacheConversation(
      ConversationModel conversation, String userId) async {
    await into(cachedConversations).insertOnConflictUpdate(
      CachedConversationsCompanion(
        id: Value(conversation.id),
        userId: Value(userId),
        createdAt: Value(conversation.createdAt),
        updatedAt: Value(conversation.updatedAt),
        lastMessage: Value(conversation.lastMessage),
        lastMessageTime: Value(conversation.lastMessageTime),
        otherUserName: Value(conversation.otherUserName),
        otherUserAvatar: Value(conversation.otherUserAvatar),
        otherUserId: Value(conversation.otherUserId),
        hasUnreadMessages: Value(conversation.hasUnreadMessages),
        unreadCount: Value(conversation.unreadCount),
        isPinned: Value(conversation.isPinned),
        isMuted: Value(conversation.isMuted),
        isArchived: Value(conversation.isArchived),
      ),
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    await (delete(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .go();
  }

  // دریافت مکالمات فقط برای userId جاری
  Future<List<ConversationModel>> getCachedConversations(String userId) async {
    final rows = await (select(cachedConversations)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
    final conversations = rows.map(_mapRowToModel).toList();
    for (final c in conversations) {
      print(
          '[ConversationCacheService] getCachedConversations: id=${c.id}, userId=$userId, unreadCount=${c.unreadCount}, hasUnreadMessages=${c.hasUnreadMessages}');
    }
    return conversations;
  }

  // Helper to map a Drift row to our app model
  ConversationModel _mapRowToModel(CachedConversation row) {
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
        isPinned: row.isPinned,
        isMuted: row.isMuted,
        isArchived: row.isArchived,
        participants: []);
  }

  // سایر متدها را نیز با userId اصلاح کن (نمونه برای updateConversation)
  Future<void> updateConversation(
      ConversationModel conversation, String userId) async {
    final existing = await getConversation(conversation.id, userId);
    if (existing != null &&
        existing.lastMessage == conversation.lastMessage &&
        existing.lastMessageTime == conversation.lastMessageTime &&
        existing.updatedAt == conversation.updatedAt &&
        existing.isPinned == conversation.isPinned &&
        existing.isMuted == conversation.isMuted &&
        existing.isArchived == conversation.isArchived) {
      return;
    }
    await into(cachedConversations).insertOnConflictUpdate(
      CachedConversationsCompanion(
        id: Value(conversation.id),
        userId: Value(userId),
        createdAt: Value(conversation.createdAt),
        updatedAt: Value(conversation.updatedAt),
        lastMessage: Value(conversation.lastMessage),
        lastMessageTime: Value(conversation.lastMessageTime),
        otherUserName: Value(conversation.otherUserName),
        otherUserAvatar: Value(conversation.otherUserAvatar),
        otherUserId: Value(conversation.otherUserId),
        hasUnreadMessages: Value(conversation.hasUnreadMessages),
        unreadCount: Value(conversation.unreadCount),
        isPinned: Value(conversation.isPinned),
        isMuted: Value(conversation.isMuted),
        isArchived: Value(conversation.isArchived),
      ),
    );
  }

  // دریافت یک مکالمه خاص برای userId
  Future<ConversationModel?> getConversation(
      String conversationId, String userId) async {
    final row = await (select(cachedConversations)
          ..where((tbl) =>
              tbl.id.equals(conversationId) & tbl.userId.equals(userId)))
        .getSingleOrNull();
    return row != null ? _mapRowToModel(row) : null;
  }

  // پاک کردن کل کش مکالمات برای userId خاص
  Future<void> clearCache(String userId) async {
    await (delete(cachedConversations)
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
  }

  // تماشای تغییرات مکالمات کش‌شده فقط برای userId
  Stream<List<ConversationModel>> watchCachedConversations(String userId) {
    return (select(cachedConversations)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch()
        .map((rows) => rows.map(_mapRowToModel).toList());
  }

  // سایر متدها (setPinStatus, setMuteStatus, setArchiveStatus, ...)
  Future<void> setPinStatus(
      String conversationId, String userId, bool isPinned) async {
    await (update(cachedConversations)
          ..where((tbl) =>
              tbl.id.equals(conversationId) & tbl.userId.equals(userId)))
        .write(CachedConversationsCompanion(isPinned: Value(isPinned)));
  }

  Future<void> setMuteStatus(
      String conversationId, String userId, bool isMuted) async {
    await (update(cachedConversations)
          ..where((tbl) =>
              tbl.id.equals(conversationId) & tbl.userId.equals(userId)))
        .write(CachedConversationsCompanion(isMuted: Value(isMuted)));
  }

  Future<void> setArchiveStatus(
      String conversationId, String userId, bool isArchived) async {
    await (update(cachedConversations)
          ..where((tbl) =>
              tbl.id.equals(conversationId) & tbl.userId.equals(userId)))
        .write(CachedConversationsCompanion(isArchived: Value(isArchived)));
  }
  // ... سایر متدها را هم به همین صورت اصلاح کن ...
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

  // ذخیره مکالمه برای کاربر خاص
  Future<void> cacheConversation(
          ConversationModel conversation, String userId) =>
      _db.cacheConversation(conversation, userId);

  // دریافت مکالمات فقط برای userId جاری
  Future<List<ConversationModel>> getCachedConversations(String userId) =>
      _db.getCachedConversations(userId);

  // اضافه شد: بروزرسانی یا درج مکالمه
  Future<void> updateConversation(
          ConversationModel conversation, String userId) =>
      _db.updateConversation(conversation, userId);

  // اضافه شد: دریافت یک مکالمه با آیدی
  Future<ConversationModel?> getConversation(
          String conversationId, String userId) =>
      _db.getConversation(conversationId, userId);

  // اضافه شد: پاک کردن کل کش مکالمات
  Future<void> clearCache(String userId) => _db.clearCache(userId);

  Future<void> removeConversation(String conversationId) async {
    // First, ensure messages related to this conversation are also cleared from message cache if necessary
    // This might be handled elsewhere or could be added here for completeness.
    // Example: await MessageCacheService().clearConversationMessages(conversationId);
    await _db.deleteConversation(conversationId);
  }

  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    // قابلیت خوانده شده حذف شد
    return;
  }

  // متد سینک برای گرفتن مکالمه از کش حافظه (Drift) بدون async
  ConversationModel? getConversationSync(String conversationId) {
    // Drift فقط متد async دارد، اما می‌توانیم یک کش ساده در حافظه نگه داریم (در صورت نیاز)
    // یا این متد را فقط برای سازگاری با کد فراخوانی‌کننده قرار دهیم و همیشه null برگردانیم
    // یا یک هشدار لاگ کنیم
    // اگر نیاز به کش حافظه داری، باید آن را اضافه کنی
    return null;
  }

  // اضافه شد: تماشای تغییرات در مکالمات کش‌شده
  Stream<List<ConversationModel>> watchCachedConversations(String userId) =>
      _db.watchCachedConversations(userId);

  Future<void> setPinStatus(
          String conversationId, String userId, bool isPinned) =>
      _db.setPinStatus(conversationId, userId, isPinned);

  Future<void> setMuteStatus(
          String conversationId, String userId, bool isMuted) =>
      _db.setMuteStatus(conversationId, userId, isMuted);

  Future<void> setArchiveStatus(
          String conversationId, String userId, bool isArchived) =>
      _db.setArchiveStatus(conversationId, userId, isArchived);

  // اضافه شد: تماشای یک مکالمه خاص برای userId
  Stream<ConversationModel?> watchConversation(
          String conversationId, String userId) =>
      _db.watchConversation(conversationId, userId);

  // سایر متدهای مورد نیاز را می‌توان اضافه کرد
}

// در ConversationCacheDatabase اضافه کن:
extension ConversationCacheDatabaseWatchExt on ConversationCacheDatabase {
  Stream<ConversationModel?> watchConversation(
      String conversationId, String userId) {
    return (select(cachedConversations)
          ..where((tbl) =>
              tbl.id.equals(conversationId) & tbl.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapRowToModel(row) : null);
  }
}
