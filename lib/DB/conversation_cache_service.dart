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
  TextColumn get otherUserName =>
      text().nullable()(); // اطمینان از وجود این فیلد
  TextColumn get otherUserAvatar => text().nullable()();
  TextColumn get otherUserId => text().nullable()();
  BoolColumn get hasUnreadMessages =>
      boolean().withDefault(const Constant(false))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  // BoolColumn get isPinned => boolean().withDefault(const Constant(false))(); // Corrected below
  // BoolColumn get isMuted => boolean().withDefault(const Constant(false))(); // Corrected below
  // BoolColumn get isArchived => boolean().withDefault(const Constant(false)); // Corrected below
  @override // اطمینان حاصل کنید که این overrideها معتبر هستند (اگر از کلاسی ارث‌بری می‌کنید)
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))(); // اضافه کردن () در انتها
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedConversations])
class ConversationCacheDatabase extends _$ConversationCacheDatabase {
  ConversationCacheDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4; // شماره نسخه را به 4 افزایش دهید

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // اگر از نسخه 1 به 2 یا بالاتر می‌رویم
          await m.addColumn(cachedConversations, cachedConversations.isPinned);
        }
        if (from < 3) {
          // اگر از نسخه 2 یا 1 به 3 یا بالاتر می‌رویم
          await m.addColumn(cachedConversations, cachedConversations.isMuted);
        }
        if (from < 4) {
          await m.addColumn(
              cachedConversations, cachedConversations.isArchived);
        }
      },
    );
  }

  @override
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
        isPinned: Value(conversation.isPinned),
        isMuted: Value(conversation.isMuted), // ذخیره وضعیت بی‌صدا
        isArchived: Value(conversation.isArchived), // ذخیره وضعیت بایگانی
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
              isPinned: row.isPinned,
              isMuted: row.isMuted, // خواندن وضعیت بی‌صدا
              isArchived: row.isArchived, // خواندن وضعیت بایگانی
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
      isPinned: row.isPinned,
      isMuted: row.isMuted, // خواندن وضعیت بی‌صدا
      isArchived: row.isArchived, // خواندن وضعیت بایگانی
      participants: [],
    );
  }

  // متد جدید: پاک کردن کل کش مکالمات
  Future<void> clearCache() async {
    await delete(cachedConversations).go();
  }

  // متد جدید: تماشای تغییرات در مکالمات کش‌شده
  Stream<List<ConversationModel>> watchCachedConversations() {
    return (select(cachedConversations)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch()
        .map((rows) => rows
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
                  isPinned: row.isPinned,
                  isMuted: row.isMuted, // خواندن وضعیت بی‌صدا
                  isArchived: row.isArchived, // خواندن وضعیت بایگانی
                  participants: [], // Participants are not stored in this simple cache table
                ))
            .toList());
  }

  // متد جدید برای تغییر وضعیت سنجاق
  Future<void> setPinStatus(String conversationId, bool isPinned) async {
    await (update(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(
      CachedConversationsCompanion(isPinned: Value(isPinned)),
    );
  }

  // متد جدید برای تغییر وضعیت بی‌صدا
  Future<void> setMuteStatus(String conversationId, bool isMuted) async {
    await (update(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(
      CachedConversationsCompanion(isMuted: Value(isMuted)),
    );
  }

  // متد جدید برای تغییر وضعیت بایگانی
  Future<void> setArchiveStatus(String conversationId, bool isArchived) async {
    await (update(cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(
      CachedConversationsCompanion(isArchived: Value(isArchived)),
    );
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
    // First, ensure messages related to this conversation are also cleared from message cache if necessary
    // This might be handled elsewhere or could be added here for completeness.
    // Example: await MessageCacheService().clearConversationMessages(conversationId);
    await _db.deleteConversation(conversationId);
  }

  Future<void> updateLastRead(String conversationId, String readTimeIso) async {
    await (_db.update(_db.cachedConversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(CachedConversationsCompanion(
      hasUnreadMessages: const Value(false),
      unreadCount: const Value(0),
      // updatedAt خیلی مهم نیست اینجا، اختیاری
    ));
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
  Stream<List<ConversationModel>> watchCachedConversations() =>
      _db.watchCachedConversations();

  Future<void> setPinStatus(String conversationId, bool isPinned) =>
      _db.setPinStatus(conversationId, isPinned);

  Future<void> setMuteStatus(String conversationId, bool isMuted) =>
      _db.setMuteStatus(conversationId, isMuted);

  Future<void> setArchiveStatus(String conversationId, bool isArchived) =>
      _db.setArchiveStatus(conversationId, isArchived);

  // سایر متدهای مورد نیاز را می‌توان اضافه کرد
}
